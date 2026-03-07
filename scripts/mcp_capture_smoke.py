#!/usr/bin/env python3

import argparse
import json
import pathlib
import select
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


class MCPClient:
    def __init__(self, server_path: str) -> None:
        self.proc = subprocess.Popen(
            [server_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.next_id = 1

    def initialize(self) -> None:
        self.request(
            "initialize",
            {
                "protocolVersion": "2025-03-26",
                "capabilities": {},
                "clientInfo": {
                    "name": "moviecapture-smoke-test",
                    "version": "0.1.0",
                },
            },
        )
        self.notify("notifications/initialized")

    def call_tool_result(self, name: str, arguments: dict | None = None) -> tuple[dict, bool, list[dict]]:
        response = self.request(
            "tools/call",
            {
                "name": name,
                "arguments": arguments or {},
            },
        )

        if "error" in response:
            raise RuntimeError(f"MCP request failed: {response['error']}")

        result = response["result"]
        content = result.get("content", [])
        if not content:
            raise RuntimeError(f"Tool {name} returned no content")

        first = content[0]
        if first.get("type") != "text":
            raise RuntimeError(f"Tool {name} returned unsupported content: {first.get('type')}")

        payload = json.loads(first["text"])
        return payload, bool(result.get("isError")), content

    def call_tool(self, name: str, arguments: dict | None = None) -> tuple[dict, bool]:
        payload, is_error, _ = self.call_tool_result(name, arguments)
        return payload, is_error

    def request(self, method: str, params: dict | None = None) -> dict:
        request_id = self.next_id
        self.next_id += 1
        message = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
        }
        if params is not None:
            message["params"] = params
        self._send(message)
        response = self._read_message(timeout=15.0)
        if response.get("id") != request_id:
            raise RuntimeError(f"Unexpected response id: {response}")
        return response

    def notify(self, method: str, params: dict | None = None) -> None:
        message = {
            "jsonrpc": "2.0",
            "method": method,
        }
        if params is not None:
            message["params"] = params
        self._send(message)

    def close(self) -> None:
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3.0)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=3.0)

    def _send(self, message: dict) -> None:
        if self.proc.stdin is None:
            raise RuntimeError("MCP stdin is unavailable")
        encoded = json.dumps(message, separators=(",", ":")).encode("utf-8") + b"\n"
        self.proc.stdin.write(encoded)
        self.proc.stdin.flush()

    def _read_message(self, timeout: float) -> dict:
        deadline = time.time() + timeout
        if self.proc.stdout is None:
            raise RuntimeError("MCP stdout is unavailable")
        if self.proc.stderr is None:
            raise RuntimeError("MCP stderr is unavailable")

        while time.time() < deadline:
            wait = max(0.0, deadline - time.time())
            ready, _, _ = select.select([self.proc.stdout, self.proc.stderr], [], [], wait)
            if not ready:
                break

            if self.proc.stderr in ready:
                stderr_line = self.proc.stderr.readline()
                if stderr_line:
                    raise RuntimeError(f"MCP stderr: {stderr_line.decode('utf-8', errors='replace').strip()}")

            if self.proc.stdout not in ready:
                continue

            line = self.proc.stdout.readline()
            if not line:
                raise RuntimeError("MCP server closed stdout unexpectedly")
            line = line.strip()
            if not line:
                continue
            message = json.loads(line.decode("utf-8"))
            if "id" not in message:
                continue
            return message

        raise TimeoutError("Timed out while reading MCP response line")


class FixtureProcess:
    def __init__(self, script_path: pathlib.Path, title_token: str, ready_file: pathlib.Path) -> None:
        self.script_path = script_path
        self.title_token = title_token
        self.ready_file = ready_file
        self.proc: subprocess.Popen[str] | None = None

    def start(self, timeout: float = 20.0) -> None:
        if not self.script_path.exists():
            raise RuntimeError(f"Fixture script not found: {self.script_path}")

        command = [
            "swift",
            str(self.script_path),
            "--title",
            self.title_token,
            "--token",
            self.title_token,
            "--width",
            "980",
            "--height",
            "740",
            "--ready-file",
            str(self.ready_file),
        ]
        self.proc = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.ready_file.exists():
                return
            if self.proc.poll() is not None:
                stdout = self.proc.stdout.read().strip() if self.proc.stdout else ""
                stderr = self.proc.stderr.read().strip() if self.proc.stderr else ""
                raise RuntimeError(
                    f"Fixture process exited early with code {self.proc.returncode}. "
                    f"stdout={stdout!r} stderr={stderr!r}"
                )
            time.sleep(0.1)

        raise TimeoutError(f"Fixture window did not become ready within {timeout:.1f}s")

    def close(self) -> None:
        if self.proc is None:
            return
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3.0)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=3.0)


def verify_recording_frame(verifier_script: pathlib.Path, output_path: pathlib.Path, capture_time: float) -> dict:
    if not verifier_script.exists():
        raise RuntimeError(f"Frame verifier script not found: {verifier_script}")

    proc = subprocess.run(
        [
            "swift",
            str(verifier_script),
            "--video",
            str(output_path),
            "--time",
            f"{capture_time:.3f}",
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "Frame verification failed")

    return json.loads(proc.stdout)


def wait_for_fixture_window(
    client: MCPClient,
    title_token: str,
    timeout: float = 10.0,
) -> dict:
    deadline = time.time() + timeout
    last_titles: list[str] = []

    while time.time() < deadline:
        list_payload, is_error = client.call_tool("list_sources", {"type": "windows", "on_screen_only": True})
        if is_error:
            raise RuntimeError(f"list_sources returned error payload: {list_payload}")

        windows = list_payload.get("windows", [])
        if any(title_token in (window.get("title") or "") for window in windows):
            return list_payload

        last_titles = [window.get("title") or "" for window in windows[:8]]
        time.sleep(0.25)

    raise RuntimeError(
        f"Fixture window was not visible in list_sources output for token {title_token}. "
        f"Recent titles: {last_titles}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a manual MCP self-capture smoke test against a native fixture window."
    )
    parser.add_argument(
        "--mcp-binary",
        default=".build/debug/moviecapture-mcp",
        help="Path to moviecapture-mcp binary",
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=2,
        help="Recording duration in seconds",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=20.0,
        help="Overall timeout for recording completion",
    )
    parser.add_argument(
        "--keep-fixture",
        action="store_true",
        help="Keep the temporary fixture file",
    )
    parser.add_argument(
        "--output",
        help="Optional explicit output path for the recorded movie",
    )
    parser.add_argument(
        "--fixture-script",
        default="scripts/capture_fixture.swift",
        help="Path to the native fixture window script",
    )
    parser.add_argument(
        "--verifier-script",
        default="scripts/verify_capture_frame.swift",
        help="Path to the recorded-frame verifier script",
    )
    return parser.parse_args()


def ffprobe_duration(path: pathlib.Path) -> float | None:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        return None

    proc = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None

    value = proc.stdout.strip()
    if not value:
        return None

    try:
        return float(value)
    except ValueError:
        return None


def main() -> int:
    args = parse_args()
    mcp_binary = pathlib.Path(args.mcp_binary).resolve()
    fixture_script = pathlib.Path(args.fixture_script).resolve()
    verifier_script = pathlib.Path(args.verifier_script).resolve()
    if not mcp_binary.exists():
        print(f"MCP binary not found: {mcp_binary}", file=sys.stderr)
        return 1
    if not fixture_script.exists():
        print(f"Fixture script not found: {fixture_script}", file=sys.stderr)
        return 1
    if not verifier_script.exists():
        print(f"Verifier script not found: {verifier_script}", file=sys.stderr)
        return 1

    fixture_root = pathlib.Path(tempfile.mkdtemp(prefix="moviecapture-smoke-"))
    fixture_token = f"MovieCaptureSmoke-{uuid.uuid4().hex[:8]}"
    fixture_ready_file = fixture_root / f"{fixture_token}.ready"
    output_path = (
        pathlib.Path(args.output).expanduser().resolve()
        if args.output
        else fixture_root / f"{fixture_token}.mov"
    )

    client: MCPClient | None = None
    fixture: FixtureProcess | None = None
    started = False

    try:
        fixture = FixtureProcess(fixture_script, fixture_token, fixture_ready_file)
        fixture.start()

        client = MCPClient(str(mcp_binary))
        client.initialize()

        list_payload = wait_for_fixture_window(client, fixture_token)

        resolve_payload, is_error = client.call_tool(
            "resolve_target",
            {
                "window": fixture_token,
                "on_screen_only": True,
            },
        )
        if is_error:
            raise RuntimeError(f"resolve_target returned error payload: {resolve_payload}")
        if resolve_payload.get("status") != "resolved":
            raise RuntimeError(f"resolve_target did not resolve uniquely: {resolve_payload}")

        target = resolve_payload["target"]
        window_id = target["recording_arguments"]["window_id"]

        still_payload, is_error, still_content = client.call_tool_result(
            "capture_still",
            {
                "window": fixture_token,
                "on_screen_only": True,
                "max_dimension": 1200,
            },
        )
        if is_error:
            raise RuntimeError(f"capture_still returned error payload: {still_payload}")
        if still_payload.get("status") != "ok":
            raise RuntimeError(f"Unexpected capture_still status: {still_payload}")
        image_content = [item for item in still_content if item.get("type") == "image"]
        if not image_content:
            raise RuntimeError("capture_still did not return image content")
        analysis = still_payload.get("analysis") or {}
        if analysis.get("is_likely_blank") is True:
            raise RuntimeError(f"capture_still returned a likely blank preview: {still_payload}")
        if analysis.get("preview_match_status") not in {"strong", "strong_metadata"}:
            raise RuntimeError(f"capture_still did not produce a strong preview match: {still_payload}")

        start_payload, is_error = client.call_tool(
            "start_recording",
            {
                "window_id": window_id,
                "duration": args.duration,
                "output": str(output_path),
            },
        )
        if is_error:
            raise RuntimeError(f"start_recording returned error payload: {start_payload}")
        if start_payload.get("status") != "recording":
            raise RuntimeError(f"Unexpected start_recording status: {start_payload}")
        if start_payload.get("advisories"):
            raise RuntimeError(f"start_recording returned unexpected advisories: {start_payload}")
        started = True

        deadline = time.time() + args.timeout
        final_status = None
        while time.time() < deadline:
            status_payload, is_error = client.call_tool("get_status")
            if is_error:
                raise RuntimeError(f"get_status returned error payload: {status_payload}")

            final_status = status_payload
            if status_payload.get("status") == "completed":
                break
            if status_payload.get("status") == "failed":
                raise RuntimeError(f"Recording failed: {status_payload}")
            time.sleep(0.5)

        if final_status is None or final_status.get("status") != "completed":
            if started:
                stop_payload, is_error = client.call_tool("stop_recording")
                if is_error:
                    raise RuntimeError(f"stop_recording returned error payload: {stop_payload}")
                final_status = stop_payload
            else:
                raise RuntimeError("Recording did not complete before timeout")

        if not output_path.exists():
            raise RuntimeError(f"Output file was not created: {output_path}")
        if output_path.stat().st_size <= 0:
            raise RuntimeError(f"Output file is empty: {output_path}")

        measured_duration = ffprobe_duration(output_path)
        if measured_duration is not None and measured_duration < max(0.5, args.duration * 0.5):
            raise RuntimeError(
                f"Recorded duration looks too short: {measured_duration:.2f}s (expected about {args.duration}s)"
            )

        frame_capture_time = min(max(0.4, args.duration * 0.5), max(0.4, args.duration - 0.2))
        verification = verify_recording_frame(verifier_script, output_path, frame_capture_time)

        summary = {
            "status": "ok",
            "fixture_title_token": fixture_token,
            "fixture_script": str(fixture_script),
            "verifier_script": str(verifier_script),
            "output_path": str(output_path),
            "output_size_bytes": output_path.stat().st_size,
            "measured_duration_seconds": measured_duration,
            "still_capture_status": still_payload["status"],
            "still_capture_size": {
                "width": still_payload["width"],
                "height": still_payload["height"],
                "byte_count": still_payload["byte_count"],
            },
            "still_capture_analysis": {
                "is_likely_blank": analysis.get("is_likely_blank"),
                "preview_match_status": analysis.get("preview_match_status"),
                "matched_query_terms_in_target_metadata": analysis.get("matched_query_terms_in_target_metadata"),
                "matched_query_terms": analysis.get("matched_query_terms"),
                "recognized_text_count": len(analysis.get("recognized_text", [])),
                "dominant_color_count": len(analysis.get("dominant_colors", [])),
            },
            "frame_verification": verification,
            "resolve_target_status": resolve_payload["status"],
            "start_recording_status": start_payload["status"],
            "start_recording_preview": start_payload.get("preview"),
            "final_status": final_status.get("status"),
        }
        print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
        return 0
    except Exception as exc:
        print(f"Smoke test failed: {exc}", file=sys.stderr)
        return 1
    finally:
        if fixture is not None:
            fixture.close()
        if client is not None:
            client.close()
        if fixture_ready_file.exists() and not args.keep_fixture:
            try:
                fixture_ready_file.unlink()
            except OSError:
                pass
        if fixture_root.exists() and not args.keep_fixture:
            try:
                fixture_root.rmdir()
            except OSError:
                pass


if __name__ == "__main__":
    sys.exit(main())

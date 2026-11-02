"""Quizforge question server.

Two endpoints, both returning the same JSON contract the app already reads:

    GET  /health      -> {"ok": true, "provider": ..., "model": ...}
    POST /generate    -> multipart file upload -> questions
    POST /regenerate  -> {"pages": [...], "count": n} -> new questions

Run it while developing:

    py server/app.py

The phone can't parse a PDF and can't hold an API key safely, so this is the
half of the product that lives off-device.

Provider behaviour: the AI is tried first. If there is no key, or the call
fails, generation falls back to the offline rule-based generator rather than
returning an error, and the response says which one ran. A demo that dies
because wifi dropped is worse than weaker questions.
"""

from __future__ import annotations

import os
import sys
import tempfile
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from flask import Flask, jsonify, request  # noqa: E402

import qfgen  # noqa: E402

app = Flask(__name__)

DEFAULT_PROVIDER = os.environ.get("QF_PROVIDER", "gemini")
DEFAULT_COUNT = 10
MAX_COUNT = 40


def _provider_ready(provider: str) -> bool:
    if provider == "gemini":
        return bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"))
    if provider == "openai":
        return bool(os.environ.get("OPENAI_API_KEY"))
    return provider == "offline"


def _generate(fn, provider: str, fallback_pages: list[dict], count: int) -> tuple[dict, str]:
    """Run the AI, degrading to the offline generator instead of failing."""
    if provider != "offline" and _provider_ready(provider):
        try:
            return fn(), provider
        except qfgen.ProviderError as e:
            app.logger.warning("provider %s failed: %s", provider, e)
    questions = qfgen.offline_questions(fallback_pages, count=count)
    return {"title": "", "questions": questions}, "offline"


@app.get("/health")
def health():
    provider = DEFAULT_PROVIDER
    return jsonify({
        "ok": True,
        "provider": provider,
        "ready": _provider_ready(provider),
        "model": os.environ.get("QF_GEMINI_MODEL", "gemini-3-flash-preview"),
    })


@app.post("/generate")
def generate():
    upload = request.files.get("file")
    if upload is None or upload.filename == "":
        return jsonify({"error": "no file uploaded"}), 400

    count = min(int(request.form.get("count", DEFAULT_COUNT)), MAX_COUNT)
    provider = request.form.get("provider", DEFAULT_PROVIDER)

    suffix = os.path.splitext(upload.filename)[1] or ".bin"
    handle, temp_path = tempfile.mkstemp(suffix=suffix)
    os.close(handle)
    try:
        upload.save(temp_path)
        extracted = qfgen.extract(temp_path)

        def ai():
            return qfgen.ai_questions(extracted, temp_path, count=count, provider=provider)

        result, used = _generate(ai, provider, extracted["pages"], count)

        return jsonify({
            "source": {
                "file": upload.filename,
                "pages": len(extracted["pages"]),
                "chars": len(qfgen.all_text(extracted)),
                "method": extracted["method"],
                "pending_images": extracted["pending_images"],
                "provider": used,
            },
            "title": result.get("title") or os.path.splitext(upload.filename)[0][:60],
            "pages": extracted["pages"],
            "questions": qfgen._clean_questions(result) if used != "offline"
                         else result["questions"],
        })
    except qfgen.ExtractError as e:
        return jsonify({"error": f"could not read that file: {e}"}), 422
    except Exception:
        app.logger.error(traceback.format_exc())
        return jsonify({"error": "generation failed"}), 500
    finally:
        try:
            os.unlink(temp_path)
        except OSError:
            pass


@app.post("/regenerate")
def regenerate():
    payload = request.get_json(silent=True) or {}
    pages = payload.get("pages") or []
    if not pages:
        return jsonify({"error": "no source text to regenerate from"}), 400

    text = "\n\n".join(str(p.get("text", "")) for p in pages).strip()
    if len(text) < 60:
        return jsonify({
            "error": "this reviewer was read as images, so there is no text to "
                     "regenerate from; upload the file again instead"
        }), 422

    count = min(int(payload.get("count", DEFAULT_COUNT)), MAX_COUNT)
    provider = payload.get("provider", DEFAULT_PROVIDER)

    def ai():
        return qfgen.ai_questions({"pages": pages, "pending_images": []},
                                  "", count=count, provider=provider)

    result, used = _generate(ai, provider, pages, count)
    questions = qfgen._clean_questions(result) if used != "offline" else result["questions"]
    return jsonify({"provider": used, "title": result.get("title", ""),
                    "questions": questions})


if __name__ == "__main__":
    port = int(os.environ.get("QF_PORT", "8765"))
    app.logger.info("Quizforge server on http://127.0.0.1:%d  (provider %s)",
                    port, DEFAULT_PROVIDER)
    app.run(host="0.0.0.0", port=port, debug=False)

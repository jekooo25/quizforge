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
        except qfgen.QualityError:
            raise  # the AI answered, it just answered about the document
        except qfgen.ProviderError as e:
            app.logger.warning("provider %s failed: %s", provider, e)
    questions = qfgen.filter_document_questions(
        qfgen.offline_questions(fallback_pages, count=count)
    )
    return {"title": "", "questions": questions}, "offline"


def _source_payload(extracted: dict, used_pages: list[int]) -> dict:
    wanted = set(used_pages)
    used = [p for p in extracted["pages"] if int(p.get("page", 0)) in wanted]
    return {
        "file": extracted["file"],
        "pages": len(extracted["pages"]),
        "used_pages": used_pages,
        "chars": sum(len(p["text"]) for p in used),
        "method": extracted["method"],
        "pending_images": extracted["pending_images"],
    }


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
    seed = int(request.form.get("seed", 0) or 0)

    suffix = os.path.splitext(upload.filename)[1] or ".bin"
    handle, temp_path = tempfile.mkstemp(suffix=suffix)
    os.close(handle)
    try:
        upload.save(temp_path)
        try:
            extracted = qfgen.extract(temp_path)
        except qfgen.ExtractError as e:
            return jsonify({"error": str(e), "code": "unreadable"}), 422
        except Exception as e:
            # a corrupt or mislabelled file: the parser threw something generic,
            # but from the student's side this is still "we couldn't read it"
            app.logger.warning("extract failed: %s", e)
            return jsonify({"error": "could not read that file", "code": "unreadable"}), 422

        try:
            page_range = qfgen.parse_page_range(
                request.form.get("pages", ""), len(extracted["pages"])
            )
        except qfgen.ExtractError as e:
            # "code" lets the app say "that page range isn't in this file"
            # instead of falling back to the generic unreadable-file message.
            return jsonify({"error": str(e), "code": "page_range"}), 422

        try:
            selection = qfgen.select_pages(extracted["pages"], page_range, seed=seed)
        except qfgen.ExtractError as e:
            return jsonify({"error": str(e), "code": "page_range"}), 422

        def ai():
            return qfgen.ai_generate(
                extracted, temp_path, count=count, provider=provider,
                page_range=page_range, seed=seed,
            )

        try:
            result, used = _generate(ai, provider, selection["pages"], count)
        except qfgen.QualityError as e:
            return jsonify({"error": str(e), "code": "quality"}), 422

        used_pages = result.get("used_pages", selection["used_pages"]) if used != "offline" \
            else selection["used_pages"]

        source = _source_payload(extracted, used_pages)
        source.update({
            "provider": used,
            "page_range": selection["requested"],
            "skipped_front_matter": result.get(
                "skipped_front_matter", selection["skipped_front_matter"]
            ),
        })
        used_set = set(used_pages)
        return jsonify({
            "source": source,
            "title": result.get("title") or os.path.splitext(upload.filename)[0][:60],
            "pages": [p for p in extracted["pages"]
                      if int(p.get("page", 0)) in used_set],
            "questions": qfgen._clean_questions(result) if used != "offline"
                         else result["questions"],
        })
    except qfgen.ExtractError as e:
        return jsonify({"error": f"could not read that file: {e}", "code": "unreadable"}), 422
    except Exception:
        app.logger.error(traceback.format_exc())
        return jsonify({"error": "generation failed", "code": "server"}), 500
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
    seed = int(payload.get("seed", 0) or 0)
    avoid = [int(p) for p in payload.get("avoid_pages", []) if str(p).isdigit()]

    try:
        if provider != "offline" and _provider_ready(provider):
            try:
                result = qfgen.regenerate_questions(
                    pages, count=count, provider=provider, seed=seed, avoid=avoid
                )
            except qfgen.QualityError:
                raise
            except qfgen.ProviderError as e:
                app.logger.warning("provider %s failed on regenerate: %s", provider, e)
                result = qfgen.regenerate_questions(
                    pages, count=count, provider="offline", seed=seed, avoid=avoid
                )
        else:
            result = qfgen.regenerate_questions(
                pages, count=count, provider="offline", seed=seed, avoid=avoid
            )
    except qfgen.QualityError as e:
        return jsonify({"error": str(e), "code": "quality"}), 422
    except qfgen.ExtractError as e:
        return jsonify({"error": str(e), "code": "unreadable"}), 422

    questions = (qfgen._clean_questions(result) if result["provider"] != "offline"
                 else result["questions"])
    return jsonify({
        "provider": result["provider"],
        "title": result.get("title", ""),
        "questions": questions,
        "used_pages": result.get("used_pages", []),
    })



if __name__ == "__main__":
    port = int(os.environ.get("QF_PORT", "8765"))
    app.logger.info("Quizforge server on http://127.0.0.1:%d  (provider %s)",
                    port, DEFAULT_PROVIDER)
    app.run(host="0.0.0.0", port=port, debug=False)

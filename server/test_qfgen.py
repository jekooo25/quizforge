"""Focused checks for the generation-quality rules. Plain asserts, no pytest.

    python -X utf8 server/test_qfgen.py
"""

from __future__ import annotations

import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import qfgen  # noqa: E402

PDF = r"C:\Users\myles\Downloads\calculus-volume-1_-_WEB.pdf"
failures = []


def check(condition: bool, message: str) -> None:
    if condition:
        print(f"  ok   {message}")
    else:
        failures.append(message)
        print(f"  FAIL {message}")


def test_page_range() -> None:
    print("-- page range --")
    check(qfgen.parse_page_range("", 100) is None, "empty means no range")
    check(qfgen.parse_page_range("40-65", 100) == (40, 65), "40-65")
    check(qfgen.parse_page_range("pages 40-65", 100) == (40, 65), "pages 40-65")
    check(qfgen.parse_page_range("40\u201365", 100) == (40, 65), "en dash")
    check(qfgen.parse_page_range("40..65", 100) == (40, 65), "40..65")
    check(qfgen.parse_page_range("40 to 65", 100) == (40, 65), "40 to 65")
    check(qfgen.parse_page_range("40", 100) == (40, 40), "single page")
    check(qfgen.parse_page_range("65-40", 100) == (40, 65), "reversed range is fixed")
    check(qfgen.parse_page_range("95-200", 100) == (95, 100), "range clamped to the file")
    try:
        qfgen.parse_page_range("chapter 4", 100)
        check(False, "garbage is rejected")
    except qfgen.ExtractError:
        check(True, "garbage is rejected")
    try:
        qfgen.parse_page_range("400-420", 100)
        check(False, "a page past the end is rejected")
    except qfgen.ExtractError:
        check(True, "a page past the end is rejected")


def test_front_matter() -> None:
    print("-- front matter --")
    pages = [
        {"page": 1, "text": ""},
        {"page": 2, "text": "Calculus Volume 1\nSENIOR CONTRIBUTING AUTHORS\nGilbert Strang"},
        {"page": 3, "text": "Copyright 2016 Rice University. All rights reserved. "
                            "ISBN 978-1-938168-02-4. Creative Commons Attribution."},
        {"page": 4, "text": "Contents\n1 Functions ........ 7\n2 Limits ........ 33\n"
                            "3 Derivatives ........ 99\n4 Applications ........ 155\n"
                            "5 Integration ........ 437\n6 Applications of Integration ........ 511\n"},
        {"page": 5, "text": "Preface\nThis textbook was written for a one-semester course. "
                            "Access for free at the publisher's site."},
        {"page": 6, "text": "A function assigns each input in its domain exactly one output. "
                            "The graph of a function can be used to read its values. "
                            "Limits describe the behaviour of a function near a point."},
    ]
    kept, skipped = qfgen.strip_front_matter(pages)
    check(skipped == [1, 2, 3, 4, 5], f"boilerplate pages skipped (got {skipped})")
    check([p["page"] for p in kept] == [6], "the content page is kept")

    only = [{"page": 1, "text": "This handout covers copyright and licence basics. "
                                "All rights reserved."}]
    kept, skipped = qfgen.strip_front_matter(only)
    check(len(kept) == 1 and skipped == [], "a single-page handout is never dropped")

    late = [{"page": i, "text": "Ordinary lesson content about derivatives and limits."}
            for i in range(1, 40)]
    late.append({"page": 40, "text": "All rights reserved. Copyright 2020. ISBN 123."})
    kept, _ = qfgen.strip_front_matter(late)
    check(any(p["page"] == 40 for p in kept), "a metadata-looking page later in the file is kept")


def test_sampling() -> None:
    print("-- sampling --")
    pages = [{"page": i, "text": ("Page %d. " % i) + ("Calculus content. " * 120)}
             for i in range(1, 101)]
    used = qfgen.select_pages(pages, budget=24000)["pages"]
    used_pages = [p["page"] for p in used]
    check(len(used_pages) > 4, "long files use more than one page")
    check(used_pages[0] < 30 and used_pages[-1] > 70,
          f"content is spread across the file (got {used_pages[0]}..{used_pages[-1]})")
    check(len({p // 12 for p in used_pages}) >= 3, "pages come from several regions")
    total = sum(len(p["text"]) for p in used)
    check(total <= 24000 + 2000, f"the budget is respected ({total} chars)")

    ranged = qfgen.select_pages(pages, page_range=(40, 65))["pages"]
    check(all(40 <= p["page"] <= 65 for p in ranged), "an explicit range is honoured")


def test_document_filter() -> None:
    print("-- document-question filter --")
    reject = [
        {"question": "What is the title of Chapter 4 in this textbook?", "explanation": ""},
        {"question": "Who are the senior contributing authors?", "explanation": ""},
        {"question": "Under which license is the textbook content released?",
         "explanation": "The copyright page names CC BY-NC-SA."},
        {"question": "What must be retained on every page if the book is redistributed?",
         "explanation": ""},
        {"question": "According to the table of contents, what is the third chapter?",
         "explanation": ""},
        {"question": "Which edition of this book is being used?", "explanation": ""},
        {"question": "How many pages does the document have?", "explanation": ""},
        {"question": "Who published this handout?", "explanation": ""},
        {"question": "What does the preface say about the course?", "explanation": ""},
    ]
    for q in reject:
        check(qfgen.is_document_question(q), "rejects: " + q["question"])

    keep = [
        {"question": "What does a licence permit the licensee to do with the work?",
         "explanation": "A licence grants permission under defined conditions."},
        {"question": "Which defence applies when a publisher repeats a defamatory claim?",
         "explanation": ""},
        {"question": "What does the author argue in the second paragraph?",
         "explanation": ""},
        {"question": "Which edition of the software introduced container support?",
         "explanation": ""},
        {"question": "What is the standard form of a linear equation?", "explanation": ""},
        {"question": "How does a rational function differ from a polynomial?",
         "explanation": ""},
        {"question": "Which formula gives the roots of a quadratic equation?",
         "explanation": ""},
        {"question": "In this chapter we compare two sorting algorithms. Which is stable?",
         "explanation": ""},
        {"question": "What is the degree of the polynomial 3x^4 - x + 2?",
         "explanation": ""},
    ]
    for q in keep:
        check(not qfgen.is_document_question(q), "keeps: " + q["question"])


def test_prompt() -> None:
    print("-- prompt --")
    pages = [{"page": 40, "text": "A linear function has the form y = mx + b."},
             {"page": 41, "text": "The quadratic formula is x = (-b +/- sqrt(b^2-4ac)) / 2a."}]
    prompt = qfgen.build_prompt(pages, 10)
    check("[[page 40]]" in prompt and "[[page 41]]" in prompt, "page markers are present")
    check('"page": 40' in prompt, "the schema asks for a page")
    check("authors" in prompt.lower() and "table of contents" in prompt.lower(),
          "the prompt forbids document questions")
    check("worked examples" in prompt.lower(), "the prompt asks for applied understanding")
    check("Ignore every page that describes the book itself"
          in qfgen.build_prompt(pages, 10, strong=True), "the stronger retry instruction exists")


def test_real_pdf() -> None:
    print("-- calculus volume 1 --")
    if not os.path.isfile(PDF):
        print("  skip (file not found)")
        return
    extracted = qfgen.extract(PDF)
    check(len(extracted["pages"]) > 700, "the whole PDF is read")
    kept, skipped = qfgen.strip_front_matter(extracted["pages"])
    check(skipped and min(skipped) <= 9, f"front matter is detected (skipped {skipped})")
    check(all(p in skipped for p in range(1, 7)),
          "the title, copyright, contents, and preface pages are skipped")
    check(any(p["page"] >= 11 for p in kept), "content pages remain after the front matter")
    selection = qfgen.select_pages(extracted["pages"], page_range=(40, 65))
    check(all(40 <= p <= 65 for p in selection["used_pages"]), "range 40-65 stays in range")
    check(len(selection["used_pages"]) >= 5, "several pages are sent")


def test_gemini_retries_then_falls_back_on_503() -> None:
    """Simulate persistent 503/UNAVAILABLE responses without calling Gemini."""
    print("-- Gemini 503 retry sequence --")
    os.environ["GEMINI_API_KEY"] = "test-key"
    os.environ["QF_GEMINI_MODEL"] = "retry-primary"
    os.environ["QF_GEMINI_FALLBACK_MODEL"] = "retry-fallback"
    calls: list[str] = []
    real_post = qfgen._post_json
    real_backoff = qfgen.RETRY_BACKOFF_SECONDS

    def always_503(url, payload, headers, timeout=120):
        calls.append(url)
        qfgen.LAST_CALLS.append({"status": 503, "error": "UNAVAILABLE"})
        raise qfgen.ProviderError("HTTP 503: UNAVAILABLE", status=503,
                                  retryable=True)

    qfgen._post_json = always_503
    qfgen.RETRY_BACKOFF_SECONDS = (0, 0)
    qfgen.reset_calls()
    try:
        try:
            qfgen.gemini_questions([{"page": 1, "text": "test source text"}])
            check(False, "persistent 503 responses raise provider-busy error")
        except qfgen.ProviderError as error:
            check(error.status == 503, "the final provider error remains a 503")
        check(len(calls) == qfgen.RETRY_ATTEMPTS * 2,
              f"each of two models gets {qfgen.RETRY_ATTEMPTS} attempts "
              f"(got {len(calls)})")
        check(all("retry-primary" in url for url in calls[:qfgen.RETRY_ATTEMPTS])
              and all("retry-fallback" in url
                      for url in calls[qfgen.RETRY_ATTEMPTS:]),
              "the fallback is called only after primary retries are exhausted")
    finally:
        qfgen._post_json = real_post
        qfgen.RETRY_BACKOFF_SECONDS = real_backoff
        qfgen.reset_calls()


def test_provider_busy() -> None:
    """Every primary and fallback attempt returns 503 before the app returns 502."""
    print("-- provider busy: retry and fallback --")
    try:
        import app as server
    except ImportError as e:  # Flask is only needed for this one check
        print(f"  skip (cannot import the server: {e})")
        return

    os.environ["GEMINI_API_KEY"] = "test-key"
    os.environ["QF_GEMINI_MODEL"] = "primary-test"
    os.environ["QF_GEMINI_FALLBACK_MODEL"] = "fallback-test"

    calls: list[str] = []
    real_post = qfgen._post_json
    real_offline = qfgen.offline_questions
    real_backoff = qfgen.RETRY_BACKOFF_SECONDS

    def always_503(url, payload, headers, timeout=120):
        calls.append(url)
        qfgen.LAST_CALLS.append({
            "status": 503,
            "raw": '{"error":{"code":503,"status":"UNAVAILABLE"}}',
            "error": "HTTP 503: UNAVAILABLE",
            "retryable": True,
        })
        raise qfgen.ProviderError("HTTP 503: UNAVAILABLE", status=503,
                                  retryable=True)

    qfgen._post_json = always_503
    qfgen.offline_questions = lambda pages, count=10, seed=0: []
    qfgen.RETRY_BACKOFF_SECONDS = (0, 0)  # no waiting in a test

    try:
        client = server.app.test_client()
        response = client.post(
            "/generate",
            data={
                # Long enough to pass the endpoint's meaningful-text guard;
                # this test is about provider failure, not input rejection.
                "file": (io.BytesIO(
                    b"The humerus is the long bone of the upper arm. "
                    b"It joins the shoulder to the elbow and supports arm movement. "
                    b"Muscles attach to named landmarks on the humerus."
                ),
                         "handout.txt"),
                "count": "10",
            },
            content_type="multipart/form-data",
        )
        body = response.get_json() or {}
        check(response.status_code == 502,
              f"a persistent 503 becomes HTTP 502 (got {response.status_code})")
        check(body.get("code") == "provider_busy",
              f"the body is tagged provider_busy (got {body.get('code')!r})")
        check("busy right now" in str(body.get("error", "")).lower()
              and "try again in a minute" in str(body.get("error", "")).lower(),
              "the body carries the friendly message")
        check(len(calls) == qfgen.RETRY_ATTEMPTS * 2,
              f"two models each tried {qfgen.RETRY_ATTEMPTS} times "
              f"(got {len(calls)} calls)")
        check(all("primary-test" in u for u in calls[:qfgen.RETRY_ATTEMPTS])
              and all("fallback-test" in u for u in calls[qfgen.RETRY_ATTEMPTS:]),
              "the fallback starts only after all primary 503 attempts")
        check(any("primary-test" in u for u in calls)
              and any("fallback-test" in u for u in calls),
              "the fallback model is tried after the primary")
    finally:
        qfgen._post_json = real_post
        qfgen.offline_questions = real_offline
        qfgen.RETRY_BACKOFF_SECONDS = real_backoff
        qfgen.reset_calls()


def main() -> int:
    test_page_range()
    test_front_matter()
    test_sampling()
    test_document_filter()
    test_prompt()
    test_gemini_retries_then_falls_back_on_503()
    test_provider_busy()
    test_real_pdf()
    print()
    if failures:
        print(f"{len(failures)} CHECK(S) FAILED")
        return 1
    print("ALL GENERATION CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

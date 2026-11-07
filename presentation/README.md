# Laptop presentation demo

Double-click these launchers in order:

1. **1 - Start Sharing Server.cmd** — keep its window open.
2. **2 - Open Teacher.cmd** — opens an independent teacher game.
3. **3 - Open Student.cmd** — opens an independent student game.

The two games use separate save folders under `presentation/sessions`. Your normal game saves are not used. Only the presentation student receives an explicitly labelled sample quiz when its shelf is empty.

## Demonstration

1. Student: **Play Quizzes** → menu beside **DEMO · General Knowledge** → **Submit to teacher**.
2. Teacher: **Pending Reviewers** → **Read reviewer** → **Approve**.
3. Teacher: **List of Reviewers** → **Publish / visibility → Code-only → Apply visibility**. Open **Shared Reviewers** to read the six-character code.
4. Student: **Shared quizzes** → enter the code → **Join quiz** → **Open My Quizzes**. Choose **REVIEW → Start Quiz Battle** on the downloaded quiz. Word-bank practice sends a separate review report when suitable source-supported sentences exist. The labelled General Knowledge sample has no source quotes; use a generated reviewer quiz to demonstrate word-bank reporting.
5. Teacher: **Shared Reviewers** → **View student results**. The editable results screen separates Quiz Battle and Word Bank, with first-attempt accuracy, practice recall, review items and completion dates.
6. Teacher: **Close sharing** to block new joins.
7. Optional public demo: teacher **Change visibility → Public → Apply visibility**. Student **Shared quizzes → Browse Public Quizzes** can add it without a code.
8. Choose **Private draft** to block new joins and remove public discovery. Existing downloads and reports remain saved.

If the server stops during play, results remain queued on the student game. Restart the server, then use **Shared quizzes → Send saved results**. Retrying the same attempt does not duplicate the teacher's report.

The database persists at `presentation/sharing-demo.sqlite3`; submissions and reports survive server restarts. Refresh teacher panels to see new submissions. The PDF-generation service is separate; this demo quiz does not require it.

## Presentation limits

This is a laptop-only prototype using local role selection, not secure account authentication. The service accepts connections only from this laptop. It does not provide internet hosting, live multiplayer, QR links, verified scores, or cross-device authentication. Use sample names and presentation data. Reopening a quiz permits a new attempt; repeated delivery of the same attempt is deduplicated.


## Quiz editor and public leaderboard

See [QUIZ EDITOR AND LEADERBOARD.txt](QUIZ%20EDITOR%20AND%20LEADERBOARD.txt) for private drafts, revision approval, optional Public leaderboards and editable scene paths. Restart the sharing server and game windows after updating.

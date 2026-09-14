-- AI Review — open a file in the AI Review Comments browser review UI.
-- Wraps the `ai-review` CLI so the app shows up in macOS "Open With"
-- (cmux / Finder: 右クリック → このアプリケーションで開く → AI Review).
--
-- REQUIRES: this app must be granted Full Disk Access
-- (System Settings → Privacy & Security → Full Disk Access),
-- otherwise it cannot read files under ~/Documents (macOS TCC / EPERM).

property nodeBin : "/opt/homebrew/bin/node"
property cliPath : "/Users/junusami/Documents/Claude仕事/ai-review-comments/cli/ai-review.mjs"

on launchReview(posixPath)
	set q to quoted form of posixPath
	-- nohup + & : detach so the review server keeps running.
	-- Logs node output to ~/Library/Logs/ai-review.log (non-protected location,
	-- so errors are visible even if Documents access is denied).
	do shell script "mkdir -p \"$HOME/Library/Logs\"; nohup " & quoted form of nodeBin & " " & quoted form of cliPath & " open " & q & " >> \"$HOME/Library/Logs/ai-review.log\" 2>&1 &"
end launchReview

-- Called when a file is dropped on / opened with this app (the normal path).
on open theFiles
	repeat with f in theFiles
		my launchReview(POSIX path of f)
	end repeat
	-- Do NOT quit: this is a background agent (LSUIElement). Quitting would
	-- also terminate the review server we just launched.
end open

-- Called only when launched directly with no file.
on run
	display notification "レビューしたいファイルを右クリック →「このアプリケーションで開く」→ AI Review で開いてください。" with title "AI Review"
end run

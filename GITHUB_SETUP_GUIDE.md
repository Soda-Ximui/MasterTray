# GitHub Setup Guide: MasterTray Workflow

**Last Updated:** 2026-06-01  
**For:** ongchau3D GitHub Account  
**Repository:** https://github.com/ongchau3D/MasterTray

---

## 🚀 Quick Start: Push Code & Create PR (5 min)

### Step 1: Create GitHub Personal Access Token (One-time Setup)

1. Go to: https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Fill in details:
   - **Token name:** `MasterTray-Push`
   - **Expiration:** 90 days (or longer)
   - **Scopes:** Check only ✓ `repo` (full control of private repositories)
4. Click **"Generate token"**
5. **⚠️ IMPORTANT:** Copy the token immediately (you won't see it again!)
6. Save it somewhere safe (password manager, note file, etc.)

**Done!** You now have a token to use instead of your password.

---

## 📤 Step 2: Configure Git Remote (One-time Setup)

Run this once to connect your local repo to GitHub:

```powershell
cd c:\repos\3D\MasterTray
git remote add origin https://github.com/ongchau3D/MasterTray.git
git remote -v   # Verify it worked (should show two lines with 'origin')
```

**Expected output:**
```
origin  https://github.com/ongchau3D/MasterTray.git (fetch)
origin  https://github.com/ongchau3D/MasterTray.git (push)
```

**Done!** Your local repo is now connected to GitHub.

---

## 🔄 Step 3: Push Your Branch (Every Time You're Ready to Share Code)

```powershell
cd c:\repos\3D\MasterTray
git push -u origin your-branch-name
```

**Example:**
```powershell
git push -u origin refactor/code-clarity-and-safety
```

**When prompted:**
- **Username:** `ongchau3D`
- **Password:** Paste your Personal Access Token (from Step 1)

**Result:** Your branch is now on GitHub! 🎉

---

## 📝 Step 4: Create a Pull Request (Every Time You Want Code Review)

### Option A: Via GitHub Web UI (Easiest)

1. Go to: https://github.com/ongchau3D/MasterTray
2. You'll see a yellow/blue banner: **"Compare & pull request"**
3. Click it
4. Fill in:
   - **Title:** Your PR title (e.g., `refactor(v4.10): Code clarity & safety improvements`)
   - **Description:** Explain what you changed (see template below)
5. Click **"Create Pull Request"**
6. Done! ✅

### Option B: Via Git Command (After Installing GitHub CLI)

```bash
gh pr create --title "Your Title Here" --body "Your description here"
```

---

## 📋 PR Description Template

Use this template for your PR description:

```markdown
## Overview
Brief summary of what this PR does.

## What Changed
- Item 1
- Item 2
- Item 3

## Why
Explain the reasoning behind these changes.

## Testing
How did you test this? What was validated?

## Backwards Compatibility
Is this backwards compatible? Any breaking changes?

## Related Issues
Closes #123 (if applicable)
```

---

## 📚 Common Git Workflows

### Workflow 1: Create New Feature Branch

```powershell
cd c:\repos\3D\MasterTray

# Update main branch first
git checkout master
git pull origin master

# Create new branch from master
git checkout -b feature/my-feature-name

# Make your changes...
# Then commit
git add .
git commit -m "feat: describe what you added"

# Push to GitHub
git push -u origin feature/my-feature-name
```

### Workflow 2: Update Existing Branch

```powershell
cd c:\repos\3D\MasterTray

# Make changes...
git add .
git commit -m "fix: describe what you fixed"

# Push (no -u flag needed - branch already exists)
git push origin feature/my-feature-name
```

### Workflow 3: Sync Your Branch with Master

```powershell
cd c:\repos\3D\MasterTray

# Fetch latest from GitHub
git fetch origin

# Rebase your branch on latest master
git rebase origin/master

# Push the updated branch (may need --force-with-lease)
git push origin feature/my-feature-name --force-with-lease
```

---

## 🔐 Security Tips

✅ **DO:**
- Store token in a password manager (1Password, LastPass, etc.)
- Use specific token names (e.g., `MasterTray-Push`)
- Set reasonable expiration (90 days)
- Create separate tokens for different purposes

❌ **DON'T:**
- Commit tokens to git
- Share tokens with others
- Use the same token for multiple projects
- Leave tokens lying around in text files

**If you accidentally leak a token:**
1. Go to https://github.com/settings/tokens
2. Find the token
3. Click **"Delete"**
4. Immediately create a new one

---

## 🐛 Troubleshooting

### Problem: "fatal: could not read Username"

**Solution:** You need to provide credentials.
```powershell
git config --global credential.helper wincred   # Use Windows Credential Manager
git push -u origin branch-name
# Now you'll get a login dialog
```

### Problem: "fatal: remote origin already exists"

**Solution:** You already added the remote. Just push:
```powershell
git push -u origin branch-name
```

### Problem: "permission denied (publickey)"

**Solution:** You're using SSH instead of HTTPS. Fix it:
```powershell
git remote remove origin
git remote add origin https://github.com/ongchau3D/MasterTray.git
git push -u origin branch-name
```

### Problem: "Everything up-to-date" but I want to update my PR

**Solution:** Make new commits and push again:
```powershell
git add .
git commit -m "update: new changes"
git push origin branch-name   # No -u flag this time
```

The PR automatically updates with your new commits!

### Problem: "Authentication failed"

**Solution:** Your token might be wrong or expired.
1. Go to https://github.com/settings/tokens
2. Generate a new token
3. Try pushing again, paste the new token

---

## 📊 Branch Naming Convention

Use these prefixes for clarity:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feature/` | New feature | `feature/snap-fit-tuning` |
| `fix/` | Bug fix | `fix/lid-alignment` |
| `refactor/` | Code refactoring | `refactor/code-clarity-and-safety` |
| `docs/` | Documentation | `docs/api-reference` |
| `chore/` | Maintenance | `chore/update-dependencies` |

---

## ✅ Checklist: Before Creating PR

- [ ] Code is committed to your branch
- [ ] Branch is pushed to GitHub
- [ ] PR title is clear and descriptive
- [ ] PR description explains what and why
- [ ] All tests pass locally
- [ ] No accidental debug code left behind
- [ ] Documentation is updated (if applicable)

---

## 🎯 After PR is Created

1. **Request Review:** Assign reviewers if needed
2. **Check for Comments:** Address any feedback
3. **Make Changes:** Push new commits to the same branch (PR auto-updates)
4. **Get Approval:** Wait for reviewer to approve
5. **Merge:** Click "Merge Pull Request" when ready
6. **Delete Branch:** GitHub offers to delete the branch after merge

---

## 🔗 Useful Links

- **GitHub Tokens:** https://github.com/settings/tokens
- **MasterTray Repo:** https://github.com/ongchau3D/MasterTray
- **Create PR:** https://github.com/ongchau3D/MasterTray/compare
- **Pull Requests:** https://github.com/ongchau3D/MasterTray/pulls
- **Git Documentation:** https://git-scm.com/doc

---

## 📝 Example: Real-World Workflow

**Scenario:** You've finished refactoring and want to create a PR.

```powershell
# 1. You've already made commits on your branch
cd c:\repos\3D\MasterTray
git status
# On branch: refactor/code-clarity-and-safety

# 2. Push to GitHub
git push -u origin refactor/code-clarity-and-safety
# Enter username: ongchau3D
# Enter password: (paste your token)

# 3. Go to GitHub and create PR
# https://github.com/ongchau3D/MasterTray
# (Click "Compare & pull request" banner)

# 4. Fill in PR details and click "Create Pull Request"

# 5. Later, someone reviews and asks for changes
# You make new commits:
git add .
git commit -m "review: address feedback on safety validation"

# 6. Push the new commits (PR auto-updates)
git push origin refactor/code-clarity-and-safety

# 7. Once approved, click "Merge Pull Request" on GitHub
# Your code is now in master! 🎉
```

---

## 🎓 Learning Resources

- **Pro Git Book:** https://git-scm.com/book/en/v2 (free!)
- **GitHub Guides:** https://guides.github.com
- **Git Basics:** https://docs.github.com/en/get-started/using-git
- **GitHub Flow:** https://guides.github.com/introduction/flow/

---

**Last Updated:** 2026-06-01  
**Questions?** Check Troubleshooting section above.

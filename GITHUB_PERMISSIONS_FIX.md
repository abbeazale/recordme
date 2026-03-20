# Fix GitHub Actions Permissions

The 403 "Resource not accessible by integration" error means GitHub Actions doesn't have permission to create releases in your repository.

## Quick Fix Options

### Option 1: Enable Workflow Permissions (Recommended)
1. Go to your GitHub repository
2. Click **Settings** tab
3. Scroll down to **Actions** → **General**
4. Under "Workflow permissions" select:
   - ✅ **Read and write permissions**
   - ✅ **Allow GitHub Actions to create and approve pull requests**
5. Click **Save**

### Option 2: Use Personal Access Token
If Option 1 doesn't work, create a PAT:

1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic) with `repo` scope
3. Copy the token
4. In your repo: Settings → Secrets and variables → Actions
5. Add new secret: `PAT_TOKEN` = your token
6. Update workflow to use `token: ${{ secrets.PAT_TOKEN }}`

### Option 3: Simplified Release Creation
Use GitHub CLI instead of action:

```yaml
- name: Create Release
  run: |
    gh release create ${{ github.ref_name }} RecordMe.dmg \
      --title "RecordMe ${{ github.ref_name }}" \
      --notes "Automated release for ${{ github.ref_name }}"
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## After Fixing Permissions
1. Delete failed release attempts (if any exist)
2. Create a new tag: `git tag v1.0.5 && git push origin v1.0.5`
3. Workflow should succeed
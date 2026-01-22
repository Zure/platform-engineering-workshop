# Contributing to Platform Engineering Workshop

## Development Workflow

### Making Changes

**⚠️ Important**: All changes must go through Pull Requests. Do not push directly to `main`.

```bash
# 1. Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix

# 2. Make your changes
# ... edit files ...

# 3. Commit changes
git add .
git commit -m "Your descriptive commit message"

# 4. Push feature branch
git push -u origin feature/your-feature-name

# 5. Create Pull Request
gh pr create --title "Your PR Title" --body "Description of changes"
```

### LAB05 Terranetes Fix

The recent Terranetes compatibility fixes (commits `4a51029` through `fce51f7`) were committed directly to main due to testing requirements and branch protection settings. This resolved the critical "Duplicate provider configuration" error.

**For future changes**: Please follow the PR workflow above.

### Testing Changes

When testing Terranetes or other Kubernetes-native tools that pull from the repository:

1. **Use feature branches**: Create PRs so changes can be reviewed
2. **Test with pushed branches**: Reference your feature branch in configurations
3. **Document testing**: Include test results in PR descriptions

## Code Review Guidelines

- All changes require review
- Include test results when applicable  
- Document breaking changes
- Update relevant documentation

## Questions?

Ask in the repository issues or reach out to maintainers.
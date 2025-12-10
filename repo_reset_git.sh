# Reset tracked files to last commit
git reset --hard

# Remove untracked files and directories
git clean -fdx

# For submodules, also reset them
git submodule foreach --recursive 'git reset --hard && git clean -fdx'

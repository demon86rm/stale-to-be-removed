# oc_updater.sh
A simple bash script that lets you install/update the following CLIs:
- oc (the tar file has a kubectl symbolic link that defaults to oc, consider that in case you have a separate *bin/kubectl)
- ocm (implementation still to be perfectioned, link might be broken)
- tkn
- kn
- rosa
- helm
- az (implementation will actually reinstall instead of checking actual version)
- aws

Feel free to add use cases, options and contributions!

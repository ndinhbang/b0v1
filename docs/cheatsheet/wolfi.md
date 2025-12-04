
```bash
apk info --help
```
Result:

```
usage: apk info [<OPTIONS>...] PACKAGES...
   or: apk info -W FILE

Description:
  apk info prints information known about the listed packages. By default, it
  prints the description, webpage, and installed size of the package
  (equivalent to apk info -dws).

Info options:
  -a, --all             List all information known about the package
  -d, --description     Print the package description
  -e, --installed       Check package installed status
  -L, --contents        List files included in the package
  -P, --provides        List what the package provides
  -r, --rdepends        List reverse dependencies of the package (all other
                        packages which depend on the package)
  -R, --depends         List the dependencies of the package
  -s, --size            Print the package's installed size
  -w, --webpage         Print the URL for the package's upstream webpage
  -W, --who-owns        Print the package which owns the specified file
  --install-if          List the package's install_if rule
  --license             Print the package SPDX license identifier
  --replaces            List the other packages for which this package is
                        marked as a replacement
  --rinstall-if         List other packages whose install_if rules refer to
                        this package
  -t, --triggers        Print active triggers for the package
```
Some popular commands:
```bash
# Print the package's installed size
apk info -s <package-name>
# List files included in a specific package
apk info -L <package-name>
# List dependencies of a specific package
apk info -R <package-name>
# List reverse dependencies of a specific package
apk info -r <package-name>
```

# Multi-line grep

```
Usage: mlgrep -h
       -h:  help

       mlgrep [-i] [-c] [-s] [-n|-l] [-q[<len>]] [-{CHJLMPRS}|-r <pattern> ...] \
              [-X] [-x <regexp> ...] [-e] [-w] [-o] [-a] [-N] <regexp> \
              [<files ...>]
```

Command flag    | Description
----------------|------------------------------------------------------------
 `-a`           | use absolute pathnames in printouts of matches
 `-i`           | ignore case
 `-w`           | match whole words only
 `-e`           | exclude self, i.e. don't search in files whose name matches the regexp we're searching for
 `-c`           | no comments (don't search within C/C++/Java/Ruby comments)
 `-s`           | no strings (don't search within double quoted strings)
 `-k`           | print statistics about occurrences of the regexp
 `-n`           | line mode (a dot (.) or \s in regexp doesn't match newline and the whole line where a match was found is printed)
 `-o`           | only match. If the regexp contains a group (a parenthesized expression), only text matching that group, rather than the entire regexp match, will be printed.
 `-l`           | list (just print names of files where a match was found)
 `-x <regexp>`  | exclude files whose names match the regexp
 `-X`           | exclude files according to 'exclude' property in ~/.mlgreprc
 `-r <pattern>` | search in files matching the pattern (e.g. -r "*.skel") The directory tree starting at current directory is searched.
 `-C`           | equivalent to `-r '*.{cc,c}'` (C, C++)
 `-H`           | equivalent to `-r '*.{hh,h}'` (C/C++ headers)
 `-J`           | equivalent to `-r '*.java'` (Java)
 `-L`           | equivalent to `-r '*.{pl,PL,pm,pod,t}'` (Perl)
 `-M`           | equivalent to `-r '{*.cmake,CMakeLists.txt}'` (CMake)
 `-P`           | equivalent to `-r '*.py'` (Python)
 `-R`           | equivalent to `-r '*.rb'` (Ruby)
 `-S`           | equivalent to `-r <'source' pattern defined in ~/.mlgreprc>`
 `-q[<len>]`    | quiet - output first <len> and last <len> characters, default is 20
 `-N`           | don't print file names and line numbers

While the unix grep is line-based, this command can search over line
breaks. Rather than printing lines where a match was found, mlgrep
prints the matching part of the file (replacing each sequence of
whitespace with a single space). Spaces in the regexp can match any
combination of whitespace in the file, and `.` (dot) matches any
character including newline. To match exactly one space, escape it
with a backslash or put it inside square brackets. To match any
character except newline, use `[^\n]`.

Option flags can be compounded. I.e., `-ics` means `-i -c -s`.

## Special regexp functionality

`\uX` (where `X` is an optionally backslash-escaped single character
or a class of characters within square brackets) matches everything up
to the first occurrence of `X` (`\u` is for *until*). For example,
`/\u;/` is replaced by `/[^;]*;/` and `/\u[123]/` is replaced by
`/[^123]*[123]/`.

Pattern options (-r, -C, -H, -J, -L, -M, -P, -S) may be combined with
each other and with <files...>.

### Examples

  Search all source code for single statements inside braces:

```sh
  > mlgrep -Ssc '[^(]\) \{[^;{}]*; \}'
```

  Search in C++ files  - excluding generated code - for null pointer check
  after allocation (which is pointless in Dicos):

```sh
  > mlgrep -x '/(generated|user|provider)' -CHc '(\w+) = (new|\w+ :: construct \()\u; [^}]* if \( \1 == (0|NULL)'
```

  Strip comments from cc files and write them to temporary files:

```sh
  [sh]$ for i in *.cc; do mlgrep -Nnc . $i > /tmp/$i; done
```

Example of ~/.mlgreprc:

```yaml
  exclude: '/(test|user|generated|provider|included|.deps|delosInfo|obj\.)'
```

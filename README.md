# bison-boilerplate

This is minimal flex/bison boilerplate for a C project with the following
requirements:

- Use autotools (automake/autoconf)
- Parse strings (not files)
- Allow for multiple parsers/lexers
- Clean interface to main program i.e., no bison/flex constructs in main program
- Clear separation between boilerplate and real parsing/lexing

The goal of the boilerplate is to be neat and tidy. That means using thread safe
Bison/flex, creating proper lex headers, using a consistent naming schema,
eschewing compiler warnings etc.

It includes a configure check that specifically checks for flex and bison, not
accepting lex nor yacc.

The boilerplate implements two identical calculator parsers to test with. Run
`autoreconf -vi && ./configure && make`, and then run with `./src/boilerplate`.
The interface between the example parsers and the main program can be seen in
main.c.

To create a parser with the boilerplate, search and replace "calc1_" with your
name, and write your lexing and parsing implementation in the sections of the .l
and .y files marked as non-boilerplate.

You can also check the [owntone1](https://github.com/ejurgensen/bison-boilerplate/tree/owntone1)
branch if you want to see the actual parsers I use the boilerplate code for.

Credit to the following for useful info/input:
* https://begriffs.com/posts/2021-11-28-practical-parsing.html
* https://github.com/meyerd/flex-bison-example
* https://github.com/5nord/bison-example
* https://lloydrochester.com/post/autotools/flex-bison-project/
* https://www.gnu.org/software/automake/manual/html_node/Yacc-and-Lex.html

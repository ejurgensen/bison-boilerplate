AC_INIT([boilerplate], [0.1])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])

AC_PROG_CC
AX_PROG_FLEX(
  [AC_DEFINE([LEX], [flex], ["flex" found])],
  AS_IF([test ! -f "$srcdir/src/calc_lexer.c"],
        [AC_MSG_ERROR([required program "flex" not found])])
)
AX_PROG_BISON(
  [AC_DEFINE([YACC], [bison], ["bison" found])],
  AS_IF([test ! -f "$srcdir/src/calc_parser.c"],
        [AC_MSG_ERROR([required program "bison" not found])])
)

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile src/Makefile])
AC_OUTPUT

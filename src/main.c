#include <stdio.h>
#include <stdlib.h>

#include "calc1_parser.h"
#include "calc2_parser.h"

static void
test1(char *input)
{
  struct calc1_result calc1_result;

  if (calc1_lex_parse(&calc1_result, input) != 0)
    printf("Parsing '%s' failed: %s\n", input, calc1_result.errmsg);
  else
    printf("%s = %g (int %d, str '%s')\n", input, calc1_result.fval, calc1_result.ival, calc1_result.str);
}

static void
test2(char *input)
{
  struct calc2_result calc2_result;

  if (calc2_lex_parse(&calc2_result, input) != 0)
    printf("Parsing '%s' failed: %s\n", input, calc2_result.errmsg);
  else
    printf("%s = %g (int %d, str '%s')\n", input, calc2_result.fval, calc2_result.ival, calc2_result.str);
}

int main(int argc, char *argv[])
{
  test1("2.2 + 3 / 2");
  test2("disco is dead");

  return 0;
}

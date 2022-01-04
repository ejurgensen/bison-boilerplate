/* =========================== BOILERPLATE SECTION ===========================*/

/* No global variables and yylex has scanner as argument */
%define api.pure true

/* Change prefix of symbols from yy to avoid clashes with any other parsers we
   may want to link */
%define api.prefix {smartpl_}

/* Gives better errors than "syntax error" */
%define parse.error verbose

/* Enables debug mode */
%define parse.trace

/* Adds output parameter to the parser */
%parse-param {struct smartpl_result *result}

/* Adds "scanner" as argument to the parses calls to yylex, which is required
   when the lexer is in reentrant mode. The type is void because caller caller
   shouldn't need to know about yyscan_t */
%param {void *scanner}

%code provides {
/* Convenience functions for caller to use instead of interfacing with lexer and
   parser directly */
int smartpl_lex_cb(char *input, void (*cb)(int, const char *));
int smartpl_lex_parse(struct smartpl_result *result, char *input);
}

/* Implementation of the convenience function and the parsing error function
   required by Bison */
%code {
  #include "smartpl_lexer.h"

  int smartpl_lex_cb(char *input, void (*cb)(int, const char *))
  {
    int ret;
    yyscan_t scanner;
    YY_BUFFER_STATE buf;
    YYSTYPE val;

    if ((ret = smartpl_lex_init(&scanner)) != 0)
      return ret;

    buf = smartpl__scan_string(input, scanner);

    while ((ret = smartpl_lex(&val, scanner)) > 0)
      cb(ret, smartpl_get_text(scanner));

    smartpl__delete_buffer(buf, scanner);
    smartpl_lex_destroy(scanner);
    return 0;
  }

  int smartpl_lex_parse(struct smartpl_result *result, char *input)
  {
    YY_BUFFER_STATE buffer;
    yyscan_t scanner;
    int retval = -1;
    int ret;

    result->errmsg[0] = '\0'; // For safety

    ret = smartpl_lex_init(&scanner);
    if (ret != 0)
      goto error_init;

    buffer = smartpl__scan_string(input, scanner);
    if (!buffer)
      goto error_buffer;

    ret = smartpl_parse(result, scanner);
    if (ret != 0)
      goto error_parse;

    retval = 0;

   error_parse:
    smartpl__delete_buffer(buffer, scanner);
   error_buffer:
    smartpl_lex_destroy(scanner);
   error_init:
    return retval;
  }

  void smartpl_error(struct smartpl_result *result, yyscan_t scanner, const char *msg)
  {
    snprintf(result->errmsg, sizeof(result->errmsg), "%s", msg);
  }

}

/* ============ ABSTRACT SYNTAX TREE (AST) BOILERPLATE SECTION ===============*/

%code {
  struct ast
  {
    int type;
    struct ast *l;
    struct ast *r;
    void *data;
  };

  __attribute__((unused)) static struct ast * new_ast(int type, struct ast *l, struct ast *r)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    a->type = type;
    a->l = l;
    a->r = r;
    return a;
  }

  /* Note *data is expected to be freeable with regular free() */
  __attribute__((unused)) static struct ast * new_data(int type, void *data)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    a->type = type;
    a->data = data;
    return a;
  }

  __attribute__((unused)) static void free_ast(struct ast *a)
  {
    if (!a)
      return;

    free_ast(a->l);
    free_ast(a->r);
    free(a->data);
    free(a);
  }

struct ast * pl_newintpredicate(int tag, int op, int value) {
  printf("Add intpred %d: %d\n", op, value);
  return NULL;
}

struct ast * pl_newdatepredicate(int tag, int op, int value) {
  printf("Add datepred %d: %d\n", op, value);
  return NULL;
}

struct ast * pl_newcharpredicate(int tag, int op, char *value) {
  printf("Add charpred %d: %s\n", op, value);
  return NULL;
}

struct ast * pl_newexpr(struct ast *arg1, int op, struct ast *arg2) {
  printf("Add ast %d\n", op);
  return NULL;
}

int pl_addplaylist(char *name, struct ast *a) {
  printf("Add playlist %s\n", name);
  return 0;
}
}

%destructor { free_ast($$); } <ast>


/* ========================= NON-BOILERPLATE SECTION =========================*/

/* Includes required by the parser rules */
%code top {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
}

/* Definition of struct that will hold the parsing result */
%code requires {
struct smartpl_result {
  char str[1024];
  int offset;
  char errmsg[128];
};
}

%union {
  unsigned int ival;
  char *cval;
  struct ast *ast;
}

%token <ival> ARTIST
%token <ival> ALBUM
%token <ival> GENRE
%token <ival> PATH
%token <ival> COMPOSER
%token <ival> ORCHESTRA
%token <ival> CONDUCTOR
%token <ival> GROUPING
%token <ival> TYPE
%token <ival> COMMENT

%token <ival> EQUALS
%token <ival> LESS
%token <ival> LESSEQUAL
%token <ival> GREATER
%token <ival> GREATEREQUAL
%token <ival> IS
%token <ival> INCLUDES

%token <ival> OR
%token <ival> AND
%token <ival> NOT

%token <cval> ID
%token <ival> NUM
%token <ival> DATE

%token <ival> YEAR
%token <ival> BPM
%token <ival> BITRATE

%token <ival> DATEADDED
%token <ival> BEFORE
%token <ival> AFTER
%token <ival> AGO
%token <ival> INTERVAL

%left OR AND

%type <ast> expression
%type <ast> predicate
%type <ival> strtag
%type <ival> inttag
%type <ival> datetag
%type <ival> dateval
%type <ival> interval
%type <ival> strbool
%type <ival> intbool
%type <ival> datebool
%type <ival> playlist

%%

playlistlist: playlist { result->str[0] = '\0'; }
| playlistlist playlist { result->str[0] = '\0'; }
;

playlist: ID '{' expression '}' { $$ = pl_addplaylist($1, $3); }
;

expression: expression AND expression { $$=pl_newexpr($1,$2,$3); }
| expression OR expression { $$=pl_newexpr($1,$2,$3); }
| '(' expression ')' { $$=$2; }
| predicate
;

predicate: strtag strbool ID { $$=pl_newcharpredicate($1, $2, $3); }
| inttag intbool NUM { $$=pl_newintpredicate($1, $2, $3); }
| datetag datebool dateval { $$=pl_newdatepredicate($1, $2, $3); }
;

datetag: DATEADDED { $$ = $1; }
;

inttag: YEAR
| BPM
| BITRATE
;

intbool: EQUALS { $$ = $1; }
| LESS { $$ = $1; }
| LESSEQUAL { $$ = $1; }
| GREATER { $$ = $1; }
| GREATEREQUAL { $$ = $1; }
| NOT intbool { $$ = $2 | 0x80000000; }
;

datebool: BEFORE { $$ = $1; }
| AFTER { $$ = $1; }
| NOT datebool { $$=$2 | 0x80000000; }
;

interval: INTERVAL { $$ = $1; }
| NUM INTERVAL { $$ = $1 * $2; }
;

dateval: DATE { $$ = $1; }
| interval BEFORE dateval { $$ = $3 - $1; }
| interval AFTER dateval { $$ = $3 + $1; }
| interval AGO { $$ = time(NULL) - $1; }
;

strtag: ARTIST
| ALBUM
| GENRE
| PATH
| COMPOSER
| ORCHESTRA
| CONDUCTOR
| GROUPING
| TYPE
| COMMENT
;

strbool: IS { $$=$1; }
| INCLUDES { $$=$1; }
| NOT strbool { $$=$2 | 0x80000000; }
;

%%


/* =========================== BOILERPLATE SECTION ===========================*/

/* This is to avoid compiler warnings about unused functions. More options are
   noyyalloc noyyrealloc noyyfree. */
%option noyywrap nounput noinput

/* Thread safe scanner */
%option reentrant

/* To avoid symbol name conflicts with multiple lexers */
%option prefix="smartpl_"

/* Automake's ylwrap expexts the output to have this name */
%option outfile="lex.yy.c"

/* Makes a Bison-compatible yylex */
%option bison-bridge

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "smartpl_parser.h"

/* Unknown why this is required despite using prefix */
#define YYSTYPE SMARTPL_STYPE
%}


/* ========================= NON-BOILERPLATE SECTION =========================*/

%{
time_t l_converttime(int day, int month, int year);
time_t l_convertyyyymmdd(char *date);
%}

%option case-insensitive

quoted \"[^\"\n]*[\"\n]
yyyymmdd  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]

%%

[\n\t ]+       /* Ignore whitespace */
\#.*\n         /* Ignore comments */

artist         { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
album_artist   { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
album          { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
title          { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
genre          { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
composer       { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
comment        { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
path           { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
type           { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }
grouping       { yylval->str = strdup(yytext); return SMARTPL_T_STRTAG; }

play_count     { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }
skip_count     { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }
rating         { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }
year           { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }
compilation    { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }
track          { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }
disc           { yylval->str = strdup(yytext); return SMARTPL_T_INTTAG; }

time_added     { yylval->str = strdup(yytext); return SMARTPL_T_DATETAG; }
time_modified  { yylval->str = strdup(yytext); return SMARTPL_T_DATETAG; }
time_played    { yylval->str = strdup(yytext); return SMARTPL_T_DATETAG; }
time_skipped   { yylval->str = strdup(yytext); return SMARTPL_T_DATETAG; }

data_kind      { yylval->str = strdup(yytext); return SMARTPL_T_DATAKINDTAG; }
media_kind     { yylval->str = strdup(yytext); return SMARTPL_T_MEDIAKINDTAG; }

               /* TODO include db.h and use real values */
file           { yylval->ival = 0; return SMARTPL_T_DATAKIND; }
url            { yylval->ival = 1; return SMARTPL_T_DATAKIND; }
spotify        { yylval->ival = 2; return SMARTPL_T_DATAKIND; }
pipe           { yylval->ival = 3; return SMARTPL_T_DATAKIND; }

music          { yylval->ival = 0; return SMARTPL_T_MEDIAKIND; }
movie          { yylval->ival = 1; return SMARTPL_T_MEDIAKIND; }
podcast        { yylval->ival = 2; return SMARTPL_T_MEDIAKIND; }
audiobook      { yylval->ival = 3; return SMARTPL_T_MEDIAKIND; }
tvshow         { yylval->ival = 4; return SMARTPL_T_MEDIAKIND; }

random         { return SMARTPL_T_RANDOM; }
limit          { return SMARTPL_T_LIMIT; }
order\ by      { return SMARTPL_T_ORDERBY; }
desc           { return SMARTPL_T_ORDER_DESC; }
asc            { return SMARTPL_T_ORDER_ASC; }

{yyyymmdd}               { yylval->ival = l_convertyyyymmdd(yytext); return (SMARTPL_T_DATE); }
today                    { yylval->ival = time(NULL); return (SMARTPL_T_DATE); }
yesterday                { yylval->ival = time(NULL) - 24*3600; return (SMARTPL_T_DATE); }
last\ week               { yylval->ival = time(NULL) - 24*3600*7; return (SMARTPL_T_DATE); }
last\ month              { yylval->ival = time(NULL) - 24*3600*30; return (SMARTPL_T_DATE); }
last\ year               { yylval->ival = time(NULL) - 24*3600*365; return (SMARTPL_T_DATE); }

days?                    { yylval->ival = 24*3600; return (SMARTPL_T_INTERVAL); }
weeks?                   { yylval->ival = 24*3600*7; return (SMARTPL_T_INTERVAL); }
months?                  { yylval->ival = 24*3600*30; return (SMARTPL_T_INTERVAL); }
years?                   { yylval->ival = 24*3600*365; return (SMARTPL_T_INTERVAL); }

ago                      { return (yylval->ival = SMARTPL_T_AGO); }
before                   { return (yylval->ival = SMARTPL_T_BEFORE); }
after                    { return (yylval->ival = SMARTPL_T_AFTER); }

is                       { return (yylval->ival = SMARTPL_T_IS); }
includes                 { return (yylval->ival = SMARTPL_T_INCLUDES); }
=                        { return (yylval->ival = SMARTPL_T_EQUALS); }

\<=                      { return (yylval->ival = SMARTPL_T_LESSEQUAL); }
\<                       { return (yylval->ival = SMARTPL_T_LESS); }
\>=                      { return (yylval->ival = SMARTPL_T_GREATEREQUAL); }
\>                       { return (yylval->ival = SMARTPL_T_GREATER); }

or                       { return SMARTPL_T_OR; }
and                      { return SMARTPL_T_AND; }
not                      { return SMARTPL_T_NOT; }

\(                       { return SMARTPL_T_LEFT; }
\)                       { return SMARTPL_T_RIGHT; }

{quoted}                { yylval->str=strdup(yytext+1);
                           if(yylval->str[strlen(yylval->str)-1] == '"')
                               yylval->str[strlen(yylval->str)-1] = '\0';
                           return (SMARTPL_T_QUOTED); }

[0-9]+                   { yylval->ival=atoi(yytext); return SMARTPL_T_NUM; }

. { return yytext[0]; }

%%

time_t l_convertyyyymmdd(char *date)
{
  char year[5];
  char month[3];
  char day[3];

  memset(year, 0, sizeof(year));
  memset(month, 0, sizeof(month));
  memset(day, 0, sizeof(day));

  strncpy(year, date, 4);
  strncpy(month, date + 5, 2);
  strncpy(day, date + 8, 2);

  return l_converttime(atoi(day), atoi(month), atoi(year));
}

time_t l_converttime(int day, int month, int year)
{
  struct tm tm;

  memset(&tm, 0, sizeof(tm));
  tm.tm_year = year - 1900;
  tm.tm_mon = month-1;
  tm.tm_mday = day;

  return mktime(&tm);
}

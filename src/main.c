#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "daap_parser.h"

struct test_query
{
  char *input;
  char *expected;
};

static struct test_query test_queries[] =
{
  {
    "'com.apple.itunes.extended-media-kind:32'",
    "(1 = 0)"
  },
  {
    "('daap.songartist!:' ('com.apple.itunes.extended-media-kind:1','com.apple.itunes.extended-media-kind:32'))",
    "((f.media_kind = 1 OR 1 = 0))"
  },
  {
    "('daap.songalbumid:1034227734086706124' ('com.apple.itunes.extended-media-kind:4','com.apple.itunes.extended-media-kind:36','com.apple.itunes.extended-media-kind:6','com.apple.itunes.extended-media-kind:7'))",
    "((f.songalbumid = 1034227734086706124 AND (((f.media_kind = 4 OR f.media_kind = 36) OR f.media_kind = 6) OR f.media_kind = 7)))"
  },
  {
    "('daap.songartistid:6912769229437698119' ('com.apple.itunes.extended-media-kind:1','com.apple.itunes.extended-media-kind:32'))",
    "((f.songartistid = 6912769229437698119 AND (f.media_kind = 1 OR 1 = 0)))"
  },
  {
    "('com.apple.itunes.playlist-contains-media-type:1','com.apple.itunes.playlist-contains-media-type:32','com.apple.itunes.playlist-contains-media-type:128','com.apple.itunes.playlist-contains-media-type:1024','com.apple.itunes.playlist-contains-media-type:65537')",
    ""
  },
  {
    "('dmap.itemname:My Music on thundarr','com.apple.itunes.extended-media-kind@1','com.apple.itunes.extended-media-kind@32','com.apple.itunes.extended-media-kind@128','com.apple.itunes.extended-media-kind@65537')",
    "(((((f.title = 'My Music on thundarr' OR f.media_kind = 1) OR 1 = 0) OR f.media_kind = 128) OR f.media_kind = 65537))"
  },
  {
    "'daap.songgenre:Kid\'s Audiobooks'",
    "(f.genre = 'Kid''s Audiobooks')"
  },
};

static void
daap_test(char *input, char *expected)
{
  struct daap_result daap_result;

  if (daap_lex_parse(&daap_result, input) != 0)
    printf("Parsing '%s' failed: %s\n", input, daap_result.errmsg);
  else if (strcmp(expected, daap_result.str) != 0)
    printf("Unexpected parse result of '%s': %s\n", input, daap_result.str);
  else
    printf("Succesful parse result of '%s': '%s'\n", input, daap_result.str);
}

int main(int argc, char *argv[])
{
  daap_test(test_queries[0].input, test_queries[0].expected);

  return 0;
}

# Sources should have _lexer.l and _parser.y suffixes
LEXER_SRC  = calc1_lexer.l calc2_lexer.l
PARSER_SRC = calc1_parser.y calc2_parser.y

# This should ensure the headers are built first. automake knows how to make
# parser headers, but doesn't know how to do that for flex. So instead we set
# the C files as target, as the AM_LFLAGS below will make sure headers are
# produced.
BUILT_SOURCES = $(LEXER_SRC:.l=.c) $(PARSER_SRC:.y=.h)

# automake doesn't know how to make lexer headers, nor does it automatically
# include them, so need to specify them as EXTRA_DIST.
EXTRA_DIST = $(LEXER_SRC:.l=.h)

# This flag is given to flex and tells it to produce headers. automake's ylwrap
# doesn't seem to rename the header like it does with the .c flex output, so
# here we give it the final name. The "$(@:.c=.h)" uses substitution reference
# and means 'change .c to .h in $@' (the target name, e.g. calc_lexer.c).
AM_LFLAGS = --header-file=$(@:.c=.h)

# This flag is given to Bison and tells it to produce headers. Note that
# automake recognizes this flag too, and has special logic around it, so don't
# change it to compound arguments (so for instance no "-dv"). I'm also not sure
# --defines will work instead of -d.
AM_YFLAGS = -d

# Enable compiler warnings
AM_CPPFLAGS = -Wall

bin_PROGRAMS = boilerplate
boilerplate_SOURCES = main.c $(LEXER_SRC) $(PARSER_SRC)

# Rule for generating lexer headers. $@ is an automatic variable that is equal
# to the particular target name, so a header file name. Disabled because headers
# are generated via AM_LFLAGS, but keep this around just in case.
#$(LEXER_SRC:.l=.h): $(LEXER_SRC)
#	$(LEX) --header-file=$@ --stdout $(@:.h=.l) > /dev/null

# Anything built by make should be cleaned by make clean, but when it comes to
# flex/bison automake's support leaves something to be desired
clean-local:
	rm -f $(LEXER_SRC:.l=.[ch]) $(PARSER_SRC:.y=.[ch])

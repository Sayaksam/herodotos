TARGET = exists

LEXER_SOURCES = exist_lexer.mll
PARSER_SOURCES = exist_parser.mly
ML_SOURCES = exists.ml csv.ml
SOURCES = $(PARSER_SOURCES:.mly=.ml) $(LEXER_SOURCES:.mll=.ml) $(ML_SOURCES)
#MENHIR_PATH=../menhirlib
#INCLUDES = -I $(MENHIR_PATH) -I ../commons
INCLUDES = -I ../commons

# Automatic computation
-include ../Makefile.config

OBJS = $(SOURCES:.ml=.cmo)
OPTOBJS = $(OBJS:.cmo=.cmx)
GENERATED= $(LEXER_SOURCES:.mll=.ml) \
	   $(PARSER_SOURCES:.mly=.ml) $(PARSER_SOURCES:.mly=.mli)
LIB=$(TARGET).cma
OPTLIB=$(LIB:.cma=.cmxa)

MENHIR=$(MENHIR_PATH)/menhirLib.cmo
MENHIRO=$(MENHIR_PATH)/menhirLib.cmx

AST_DEPEND=ast_exist

# The Caml compilers.
OCAMLCFLAGS ?= -g -dtypes $(FLAGS)
OCAMLC =ocamlc$(OPTBIN) $(OCAMLCFLAGS) $(INCLUDES)
OCAMLOPT = ocamlopt$(OPTBIN) $(OPTFLAGS) $(INCLUDES)
OCAMLLEX = ocamllex$(OPTBIN)
OCAMLYACC= menhir $(OCAMLYACCOPT) --infer
OCAMLDEP = ocamldep$(OPTBIN) #$(INCLUDES)

all: $(LIB)
all.opt: $(OPTLIB)

.SUFFIXES:
.SUFFIXES: .ml .mli .cmo .cmi .cmx

.ml.cmo:
	$(OCAMLC) -c $<

.mli.cmi:
	$(OCAMLC) -c $<

.ml.cmx:
	$(OCAMLOPT) -c $<

$(LEXER_SOURCES:.mll=.ml) :	$(LEXER_SOURCES)
	$(OCAMLLEX) $(LEXER_SOURCES)

$(PARSER_SOURCES:.mly=.ml) $(PARSER_SOURCES:.mly=.mli) : $(AST_DEPEND).cmi $(PARSER_SOURCES)
	$(OCAMLYACC) $(PARSER_SOURCES)

$(LIB): $(GENERATED) $(OBJS)
	$(OCAMLC) -a -o $(LIB) $(OBJS)

$(OPTLIB): $(GENERATED) $(OPTOBJS)
	$(OCAMLOPT) -a -o $(OPTLIB) $(OPTOBJS)

clean::
	rm -f $(TARGET)
	rm -f $(GENERATED)
	rm -f *.cm[aiox] *.cmxa *.a *.o *.annot
	rm -f *~ .*~

distclean: clean
	rm -f .depend

.depend depend:
	$(OCAMLYACC) --depend $(PARSER_SOURCES) > .depend
	$(OCAMLDEP) $(ML_SOURCES) >> .depend

-include .depend

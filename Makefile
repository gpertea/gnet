GDIR := ../gclib
INCDIRS := -I. -I${GDIR}

# C++ compiler
CC      := g++

# C/C++ linker
LINKER  := g++

ifneq (,$(findstring nothreads,$(MAKECMDGOALS)))
 NOTHREADS=1
endif

#detect MinGW (Windows environment)
#ifneq (,$(findstring mingw,$(shell ${CC} -dumpmachine)))
# WINDOWS=1
#endif


# Misc. system commands
#ifdef WINDOWS
#RM = del /Q
#else
RM = rm -f
#endif

LFLAGS = 
# MinGW32 GCC 4.5 link problem fix
#ifdef WINDOWS
ifneq (,$(findstring 4.5.,$(shell g++ -dumpversion)))
 LFLAGS += -static-libstdc++ -static-libgcc
endif
#endif

# File endings
ifdef WINDOWS
EXE = .exe
else
EXE =
endif

BASEFLAGS  := -Wall -Wextra ${INCDIRS} -D_FILE_OFFSET_BITS=64 \
-D_LARGEFILE_SOURCE -fno-strict-aliasing -fno-exceptions -fno-rtti

#LIBS := -lz
LIBS :=

# Non-windows systems need pthread
ifndef WINDOWS
 ifndef NOTHREADS
   LIBS += -lpthread
 endif
endif

#ifdef NOTHREADS
#  BASEFLAGS += -DNOTHREADS
#endif


ifneq (,$(filter %release %static, $(MAKECMDGOALS)))
  # -- release build
  CFLAGS := -O3 -DNDEBUG -g $(BASEFLAGS)
  LDFLAGS := -g ${LFLAGS}
  ifneq (,$(findstring static,$(MAKECMDGOALS)))
    LDFLAGS += -static-libstdc++ -static-libgcc
  endif
else
  ifneq (,$(filter %memcheck %memdebug, $(MAKECMDGOALS)))
     #make memcheck : use the statically linked address sanitizer in gcc 4.9.x
     GCCVER49 := $(shell expr `g++ -dumpversion | cut -f1,2 -d.` \>= 4.9)
     ifeq "$(GCCVER49)" "0"
       $(error gcc version 4.9 or greater is required for this build target)
     endif
     CFLAGS := -fno-omit-frame-pointer -fsanitize=undefined -fsanitize=address $(BASEFLAGS)
     GCCVER5 := $(shell expr `g++ -dumpversion | cut -f1 -d.` \>= 5)
     ifeq "$(GCCVER5)" "1"
       CFLAGS += -fsanitize=bounds -fsanitize=float-divide-by-zero -fsanitize=vptr
       CFLAGS += -fsanitize=float-cast-overflow -fsanitize=object-size
       #CFLAGS += -fcheck-pointer-bounds -mmpx
     endif
     CFLAGS := -g -DDEBUG -D_DEBUG -DGDEBUG -fno-common -fstack-protector $(CFLAGS)
     LDFLAGS := -g
     #LIBS := -Wl,-Bstatic -lasan -lubsan -Wl,-Bdynamic -ldl $(LIBS)
     LIBS := -lasan -lubsan -ldl $(LIBS)
  else
  # ifneq (,$(filter %memtrace %memusage %memuse, $(MAKECMDGOALS)))
  #     BASEFLAGS += -DGMEMTRACE
  #     GMEMTRACE=1
  # endif
  # #just plain debug build
    CFLAGS := -g -DDEBUG -D_DEBUG -DGDEBUG $(BASEFLAGS)
    LDFLAGS := -g
  endif
endif

%.o : %.cpp
	${CC} ${CFLAGS} -c $< -o $@

OBJS := ${GDIR}/GBase.o ${GDIR}/GArgs.o ${GDIR}/GStr.o \
   ${GDIR}/gsocket.o

#ifdef GMEMTRACE
# OBJS += ${GDIR}/proc_mem.o
#endif

ifndef NOTHREADS
 OBJS += ${GDIR}/GThreads.o 
endif

all release static debug: gnet
memcheck memdebug: gnet
memuse memusage memtrace: gnet
nothreads: gnet

$(GDIR)/gsocket.o : $(GDIR)/gsocket.h
gnet.o : $(GDIR)/GBase.h $(GDIR)/gsocket.h
gnet: $(OBJS) gnet.o
	${LINKER} ${LDFLAGS} -o $@ ${filter-out %.a %.so, $^} ${LIBS}

.PHONY : clean
# target for removing all object files
clean:
	@${RM} gnet gnet.o* gnet.exe $(OBJS)
	@${RM} core.*

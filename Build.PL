use strict;
use warnings;
use Module::Build;
use ExtUtils::CppGuess;

my $builder = Module::Build->new(
    module_name         => 'Math::Geometry::Delaunay',
    license             => 'perl',
    dist_author         => q{Michael E. Sheldrake <sheldrake@cpan.org>},
    configure_requires  => {
        'Module::Build' => '0.38',
        'ExtUtils::CppGuess' => 0,
        },
    build_requires => {
        'Test::More' => 0,
        'ExtUtils::CBuilder' => 0,
    },
    c_source            => ['src'],
    xs_files            => {'Delaunay.xs' => 'lib/Math/Geometry/Delaunay.xs'},
    
    # FLAGS FOR TRIANGLE
    # We want to include -DREDUCED, but it looks like that might take 
    # away the D option, even though the docs indicate otherwise. 
    # (Also, not sure the D option works, but need to test that more.)

    extra_compiler_flags => [qw(
                                -DREAL=double 
                                -DTRILIBRARY 
                                -DANSI_DECLARATORS 
                                -DNO_TIMER
                               )
                            ],
    add_to_cleanup      => [ 'Math-Geometry-Delaunay-*' ],
);

# Triangle disables extended-precision doubles on x86 processors to make its
# exact arithmatic routines, which depend on the rounding error of normal-precision
# doubles, work properly. How to disable extended-precision doubles is 
# compiler-specific, and Triangle will do the right thing for x86 processors
# compiling with gcc under Linux or MSVC, if we pass either the LINUX
# or CPU86 compiler flag.

# However,
# we're also going to use xpfpa.h from 
# http://www.christian-seiler.de/projekte/fpmath/
# to try to set the FPU state, and more significantly, to restore the state
# to whateverever it was before each call to triangulate().
# The HAVE__CONTROLFP (Microsoft) and HAVE__FPU_SETCW (Linux) flags will give us
# the right macros for the platform.

# For Cygwin, we try to compile so we're always in normal precision mode.
# There is no runtime attempt to set or restore precision of doubles under
# Cygwin, because there does not appear to be a function available to do it.

my $compiler = ExtUtils::CppGuess->new();

if ($compiler->is_gcc) {
    if ($^O =~ /MSWin32/i) { # MinGW - untested
        push @{$builder->extra_compiler_flags()}, "-DCPU86", "-DHAVE__CONTROLFP";
        }
    elsif ($^O =~ /cygwin/) {
        # Use SSE2, which doesn't use extended precision doubles,
        # or, if SSE2 flags don't work, hopefully fall back (-mpc64)
        # to locking fpu into normal precision.
        push @{$builder->extra_compiler_flags()}, "-march=native", "-mfpmath=sse", "-msse2", "-mpc64";

        # Cygwin's Perl 5.14, as of about June 2012, has usemymalloc=n, 
        # so shouldn't get here, and should behave like most other Perls 
        # that use the system's malloc/free.
        # But Cygwin's older Perl 5.10 (and earlier?) has usemymalloc=y, so
        # this substitutes "malloc" and "free" in Triangle with Perl's versions.
        if ($builder->config('usemymalloc') eq 'y') {
            push @{$builder->extra_compiler_flags()}, "-Dfree=Perl_mfree", "-Dmalloc=Perl_malloc";
            } 
        }
    elsif ($^O =~ /linux/i) {
        push @{$builder->extra_compiler_flags()}, "-DLINUX", "-DHAVE__FPU_SETCW";
        }
    # else hope the system is in normal precision double mode by default
    }
elsif ($compiler->is_msvc) {
    push @{$builder->extra_compiler_flags()}, "-DCPU86";
    }
# Based on Perl configure hints that set usemymalloc=y for certain platforms
# we blindly take the same approach that worked with Cygwin and Perl 5.10
# for a few other platforms to get free() working without crashing, we hope.
# 
# Untested.
elsif (
    $builder->config('usemymalloc') eq 'y' &&
        (
        $builder->config('archname') eq 'OPENSTEP-Mach' || # NeXT 4
        $^O eq 'unicosmk' || # Cray ca. 1995
        $^O eq 'hpux' || 
        $^O eq 'openbsd' ||
        $builder->config('archname') =~ /super.?ux/i # maybe, NEC supercomputer OS
        )
    ) {
    push @{$builder->extra_compiler_flags()}, "-Dfree=Perl_mfree", "-Dmalloc=Perl_malloc";
    }

$builder->create_build_script();
use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ MakeMaker => ],
                    [ VerifyPhases => ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    $tzil->build;

    cmp_deeply(
        [
            grep { /\[VerifyPhases\]/ }
            # TODO: waiting for https://github.com/rjbs/Dist-Zilla/pull/229
            grep { ! /^\[VerifyPhases\] file has been added after munging phase: 'Makefile.PL'/ }
                @{ $tzil->log_messages }
        ],
        [],
        'no warnings from the plugin despite Makefile.PL being modified late',
    )
    or diag 'got messages: ', explain $tzil->log_messages;
}

done_testing;


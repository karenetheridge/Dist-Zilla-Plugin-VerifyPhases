use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Path::Tiny;

my $added_line;
{
    package Dist::Zilla::Plugin::Naughty;
    use Moose;
    with
        'Dist::Zilla::Role::FileGatherer',
        'Dist::Zilla::Role::PrereqSource',
        'Dist::Zilla::Role::FileInjector';

    sub gather_files
    {
        my $self = shift;
        my $distmeta = $self->zilla->distmeta;  # make the attribute fire
    }
    sub register_prereqs
    {
        my $self = shift;
        require Dist::Zilla::File::InMemory;
        $added_line = __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file',
            content => 'naughty naughty!',
        ));
    }
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ Naughty => ],
                    [ VerifyPhases => ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    $tzil->build;

    cmp_deeply(
        [ grep { /\[VerifyPhases\]/ } @{ $tzil->log_messages } ],
        bag(
            '[VerifyPhases] distmeta has already been calculated after file gathering phase!',
            "[VerifyPhases] file has been added after munging phase: \'rogue_file\' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line))",
        ),
        'warnings are logged about our naughty plugin',
    )
    or diag explain $tzil->log_messages;
}

done_testing;

use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Path::Tiny;

my @added_line;
{
    package Dist::Zilla::Plugin::Naughty;
    use Moose;
    with
        'Dist::Zilla::Role::FileGatherer',
        'Dist::Zilla::Role::PrereqSource',
        'Dist::Zilla::Role::FileInjector';
    use Dist::Zilla::File::InMemory;
    use List::MoreUtils 'first_value';

    sub gather_files
    {
        my $self = shift;
        my $distmeta = $self->zilla->distmeta;  # make the attribute fire
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_0',
            content => 'oh hai!',
        ));
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_1',
            content => 'oh hai!',
        ));
    }
    sub register_prereqs
    {
        my $self = shift;

        $self->zilla->prune_file(first_value { $_->name eq 'normal_file_0' } @{$self->zilla->files});

        my $file1 = first_value { $_->name eq 'normal_file_1' } @{$self->zilla->files};
        $file1->name('normal_file_1_moved');

        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file_2',
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
            "[VerifyPhases] file has been removed after munging phase: 'normal_file_0' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[0]))",
            "[VerifyPhases] file has been renamed after munging phase: 'normal_file_1_moved' (originally 'normal_file_1', content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[1]))",
            "[VerifyPhases] file has been added after munging phase: 'rogue_file_2' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[2]))",
        ),
        'warnings are logged about our naughty plugin',
    )
    or diag explain $tzil->log_messages;
}

done_testing;

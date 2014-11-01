use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Path::Tiny;

my (@content_line, @filename_line);
{
    package Dist::Zilla::Plugin::Naughty;
    use Moose;
    with
        'Dist::Zilla::Role::FileGatherer',
        'Dist::Zilla::Role::FileMunger',
        'Dist::Zilla::Role::PrereqSource',
        'Dist::Zilla::Role::FileInjector';
    use Dist::Zilla::File::InMemory;
    use List::Util 'first';

    sub gather_files
    {
        my $self = shift;
        my $distmeta = $self->zilla->distmeta;  # make the attribute fire
        my $version = $self->zilla->version;    # make the attribute fire
        push @content_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_0',
            content => 'oh hai!',
        ));
        push @content_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_1',
            content => 'oh hai!',
        ));
        push @content_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_2',
            content => 'oh hai!',
        ));
    }
    sub munge_files
    {
        my $self = shift;

        # okay to rename files at munge time
        my $file0 = first { $_->name eq 'normal_file_0' } @{$self->zilla->files};
        push @filename_line, __LINE__; $file0->name('normal_file_0_moved');

        # not okay to remove files at munge time
        $self->zilla->prune_file(first { $_->name eq 'normal_file_2' } @{$self->zilla->files});

        # not okay to add files at munge time
        push @content_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file_3',
            content => 'naughty naughty!',
        ));
    }
    sub register_prereqs
    {
        my $self = shift;

        # not okay to remove files at prereq time
        $self->zilla->prune_file(first { $_->name eq 'normal_file_0_moved' } @{$self->zilla->files});

        # not okay to rename files at prereq time
        my $file1 = first { $_->name eq 'normal_file_1' } @{$self->zilla->files};
        push @filename_line, __LINE__; $file1->name('normal_file_1_moved');

        # not okay to add files at prereq time
        push @content_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file_4',
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

    my $verb = Dist::Zilla->VERSION < 5.023 ? 'set' : 'added';

    cmp_deeply(
        [ grep { /\[VerifyPhases\]/ } @{ $tzil->log_messages } ],
        bag(
            '[VerifyPhases] distmeta has already been calculated by end of file gathering phase!',
            '[VerifyPhases] version has already been calculated by end of file gathering phase!',
            "[VerifyPhases] file has been removed by end of file pruning phase: 'normal_file_0_moved' (content $verb by Naughty (Dist::Zilla::Plugin::Naughty line $content_line[0])" . (Dist::Zilla->VERSION < 5.023 ? '' : "; filename set by Naughty (Dist::Zilla::Plugin::Naughty line $filename_line[0])") . ")",
            "[VerifyPhases] file has been renamed by end of munging phase: 'normal_file_1_moved' (originally 'normal_file_1', content $verb by Naughty (Dist::Zilla::Plugin::Naughty line $content_line[1])" . (Dist::Zilla->VERSION < 5.023 ? '' : "; filename set by Naughty (Dist::Zilla::Plugin::Naughty line $filename_line[1])") . ")",
            "[VerifyPhases] file has been removed by end of file pruning phase: 'normal_file_2' (content $verb by Naughty (Dist::Zilla::Plugin::Naughty line $content_line[2]))",
            "[VerifyPhases] file has been added by end of file gathering phase: 'rogue_file_3' (content $verb by Naughty (Dist::Zilla::Plugin::Naughty line $content_line[3]))",
            "[VerifyPhases] file has been added by end of file gathering phase: 'rogue_file_4' (content $verb by Naughty (Dist::Zilla::Plugin::Naughty line $content_line[4]))",
        ),
        'warnings are logged about our naughty plugin',
    );

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;

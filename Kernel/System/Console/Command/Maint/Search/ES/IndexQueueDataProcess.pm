# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Search::ES::IndexQueueDataProcess;

use strict;
use warnings;
use POSIX;
use Kernel::System::VariableCheck qw(:all);

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Search',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description(
        'Process queued index data operations.'
    );

    $Self->AddOption(
        Name => 'refresh',
        Description =>
            "Refresh data on rebuilding.",
        Required => 0,
        HasValue => 0,
        Multiple => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    if ( !$Self->{SearchObject} || $Self->{SearchObject}->{Error} ) {
        my $Message = "Errors occured. Exiting.";
        if ( !$Self->{SearchObject}->{ConnectObject} ) {
            $Message = "Could not connect to the cluster.";
        }
        $Self->Print("<red>$Message\n</red>");
        $Self->{Abort} = 1;
        return;
    }

    $Self->{Refresh} = $Self->GetOption('refresh');

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return $Self->ExitCodeError() if ( $Self->{Abort} );
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');

    my @ActiveIndexes;
    my @IndexList = $Self->{SearchObject}->IndexList();

    # execute only on registered indexes that exists in the cluster
    INDEX:
    for my $IndexRealName (@IndexList) {
        my $IndexName = $SearchChildObject->IndexIsValid(
            IndexName => $IndexRealName,
            RealName  => 1,
        );

        push @ActiveIndexes, $IndexName if $IndexName;
    }

    my $RebuildedObjectSets = {
        Failed  => 0,
        Success => 0,
    };

    my $ReindexationSettings = $ConfigObject->Get('SearchEngine::Reindexation')->{Settings};
    my $ReindexationStep     = $ReindexationSettings->{ReindexationStep} // 500;

    INDEX:
    for my $IndexName (@ActiveIndexes) {

        # support for generic index operations
        OPERATION:
        for my $Operation (qw(ObjectIndexSet ObjectIndexAdd ObjectIndexRemove ObjectIndexUpdate)) {
            my @ObjectIDs;
            my $ObjectData = $SearchChildObject->ObjectToProcessSearch(
                Index     => $IndexName,
                Operation => $Operation,
            ) // [];

            for my $Data ( @{$ObjectData} ) {
                if ( IsHashRefWithData($Data) && $Data->{ObjectID} ) {
                    push @ObjectIDs, $Data->{ObjectID};
                }
            }

            my $ObjectCount = scalar @ObjectIDs;
            next OPERATION if !$ObjectCount;

            my $ObjectPartValues;

            $Self->Print(
                "<yellow>Index $IndexName queued operation will be done in parts with step: $ReindexationStep per each set of data. Operation: $Operation.</yellow>\n"
            );

            # rebuild data in parts to not over-load Elasticsearch
            if ( $ObjectCount <= $ReindexationStep ) {
                $ObjectPartValues = [ \@ObjectIDs ];
            }
            elsif ( $ReindexationStep > 0 ) {

                # separate Object ids into parts with reindexing step count
                # example: reindexation step: 500
                # object ids count to rebuild: 1020
                # result: [[1 .. 500][501 .. 1000][1001 .. 1020]]
                my $ObjectPartCount = ceil( $ObjectCount / $ReindexationStep );
                my $Start           = 0;

                for my $PartCount ( 1 .. $ObjectPartCount ) {
                    my @PartObjectIDs = @ObjectIDs[ $Start .. $Start + $ReindexationStep - 1 ];
                    $Start += $ReindexationStep;

                    if ( $PartCount == $ObjectPartCount ) {
                        @PartObjectIDs = grep {$_} @PartObjectIDs;
                    }
                    push @{$ObjectPartValues}, \@PartObjectIDs;
                }
            }

            OBJECT_SET:
            for my $ObjectIDsSet ( @{$ObjectPartValues} ) {
                next OBJECT_SET if !IsArrayRefWithData($ObjectIDsSet);
                my $Result = $Self->{SearchObject}->$Operation(
                    Index    => $IndexName,
                    ObjectID => $ObjectIDsSet,
                    Refresh  => $Self->{Refresh},
                );

                if ($Result) {
                    $RebuildedObjectSets->{Success}++;
                    $SearchChildObject->ObjectToProcessDelete(
                        Index     => $IndexName,
                        Operation => 'ObjectIndexSet',
                        ObjectID  => $ObjectIDsSet,
                    );
                }
                else {
                    $RebuildedObjectSets->{Failed}++;
                }
            }
        }
    }

    $Self->Print(
        "<green>$RebuildedObjectSets->{Success} object(s) sets was rebuilded for Elasticsearch.</green>\n"
    );
    if ( $RebuildedObjectSets->{Failed} ) {
        $Self->Print(
            "<red>$RebuildedObjectSets->{Failed} object(s) sets rebuilding failed for Elasticsearch.\n
            Those object ids wasn't deleted from the queue.</red>\n"
        );
    }

    return $Self->ExitCodeOk();
}

1;

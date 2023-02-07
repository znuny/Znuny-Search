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

    my $RebuildedObjectQueries = {
        Failed  => 0,
        Success => 0,
    };

    my $IndexationQueueConfig = $ConfigObject->Get("SearchEngine::IndexationQueue") // {};
    my $TTL                   = $IndexationQueueConfig->{Settings}->{TTL} || 180;

    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    INDEX:
    for my $IndexName (@ActiveIndexes) {

        # get queued data for indexing
        my $CachedValue = $CacheObject->Get(
            Type => 'SearchEngineIndexQueue',
            Key  => "Index::$IndexName",
        );

        next INDEX if !defined $CachedValue;

        if ( ref $CachedValue ne 'ARRAY' ) {
            $CacheObject->Delete(
                Type => 'SearchEngineIndexQueue',
                Key  => "Index::$IndexName",
            );

            next INDEX;
        }

        my @QueuesToExecute;
        my %ObjectIDData;

        # check for either object id or query params
        for my $QueuedData ( @{$CachedValue} ) {
            my $ObjectID = $QueuedData->{ObjectID};
            if ($ObjectID) {

                # do not push object id operation into an array yet
                # the last one will be assigned here for each object data
                $ObjectIDData{$ObjectID} = $QueuedData;
            }
            elsif ( $QueuedData->{QueryParams} ) {

                # push query params every time as we can't identify
                # what object id it will match
                push @QueuesToExecute, $QueuedData;
            }
        }

        # object id data should contain only last
        # operation found for specified data
        # push them now on the indexing queue
        for my $ObjectID ( sort keys %ObjectIDData ) {
            push @QueuesToExecute, $ObjectIDData{$ObjectID};
        }

        for ( my $i = 0; $i < scalar @QueuesToExecute; $i++ ) {
            my %QueueData = %{ $QueuesToExecute[$i] };

            my $FunctionName = $QueueData{FunctionName};
            my %Query        = $QueueData{QueryParams}
                ?
                (
                QueryParams => $QueueData{QueryParams},
                )
                :
                (
                ObjectID => $QueueData{ObjectID},
                );

            %QueueData = ( %QueueData, %Query );

            my $Success = $Self->{SearchObject}->$FunctionName(
                Index   => $IndexName,
                Refresh => 0,
                %QueueData,
            );

            if ( !$Success ) {
                $RebuildedObjectQueries->{Failed}++;
            }
            else {
                $RebuildedObjectQueries->{Success}++;
            }
        }

        # get again cached values just in cases more was added into the queue
        # while actual iteration was executing
        my $CachedValueReGet = $CacheObject->Get(
            Type => 'SearchEngineIndexQueue',
            Key  => "Index::$IndexName",
        );

        if ( @{$CachedValueReGet} == @{$CachedValue} ) {

            # case where nothing has been added
            # delete cache of operation queue that was processed
            $CacheObject->Delete(
                Type => 'SearchEngineIndexQueue',
                Key  => "Index::$IndexName",
            );
        }
        else {
            # meantime queue execution, it could only be extended
            # this means that only new operations should be
            # saved into the cache
            if ( ref $CachedValueReGet eq 'ARRAY' && ref $CachedValue eq 'ARRAY' ) {
                my $CachedCount      = scalar @{$CachedValue};
                my $CachedReGetCount = scalar @{$CachedValueReGet};

                my @CacheToSet;
                if ( $CachedCount < $CachedReGetCount ) {

                    # case where there was nothing cached, but meantime something was added
                    # to the queue (nothing needs to be done as cached queue is updated)
                    next INDEX if ( $CachedCount == 0 );

                    # example case:
                    # elasticsearch had a queue of 100 object data to index
                    # it took 500 ms of time, in the meantime 5 new objects was added to the cached
                    # queue - those needs to be assigned into queue without old ones
                    # queue looks now like this: [100 old data, 5 new data]
                    # simply set cache to only new ones to be processed in the next iteration of the
                    # command
                    @CacheToSet = @{$CachedValueReGet}[ $CachedCount .. scalar @{$CachedValueReGet} - 1 ];

                    # set new cache data
                    $CacheObject->Set(
                        Type  => 'SearchEngineIndexQueue',
                        Key   => "Index::$IndexName",
                        Value => \@CacheToSet,
                        TTL   => $TTL,
                    );
                }
            }

        }

    }

    $Self->Print(
        "<green>Successfully executed $RebuildedObjectQueries->{Success} object queries for Elasticsearch.</green>\n"
    );
    if ( $RebuildedObjectQueries->{Failed} ) {
        $Self->Print(
            "<red>Execution of $RebuildedObjectQueries->{Failed} object queries failed for Elasticsearch.\n</red>\n"
        );
    }

    return $Self->ExitCodeOk();
}

1;

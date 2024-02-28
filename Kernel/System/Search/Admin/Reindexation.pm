# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## nofilter(TidyAll::Plugin::Znuny::Perl::LayoutObject)

package Kernel::System::Search::Admin::Reindexation;

use strict;
use warnings;
use Proc::Find qw(find_proc proc_exists);

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DB',
    'Kernel::System::PID',
    'Kernel::System::Search',
    'Kernel::System::Search::Cluster',
    'Kernel::System::Cache',
    'Kernel::System::JSON',
    'Kernel::System::Search::Object',
    'Kernel::System::Console::Command::Maint::Search::Reindex',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Admin::Reindexation - admin re-indexation, lib

=head1 DESCRIPTION

Cluster re-indexation, base backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

    my $SearchAdminDetailsObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    bless( $Self, $Type );

    return $Self;
}

=head2 BuildReindexationSection()

build re-indexation, section

    my $Details = $ReindexationObject->BuildReindexationSection(
        ClusterConfig => $ClusterConfig,
        UserID => $UserID,
    );

=cut

sub BuildReindexationSection {
    my ( $Self, %Param ) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchObject  = $Kernel::OM->Get('Kernel::System::Search');
    my $PIDObject     = $Kernel::OM->Get('Kernel::System::PID');
    my $ClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $CacheObject   = $Kernel::OM->Get('Kernel::System::Cache');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');

    my $ClusterConfig = $ClusterObject->ActiveClusterGet();
    my $Output        = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    my $ReindexationStatus  = $Self->IndexReindexationStatus();
    my $IsReindexingOngoing = $ReindexationStatus->{IsReindexingOngoing};

    my %IconMapping = (
        Done    => 'fa-check',
        Ongoing => 'fa-refresh fa-spin',
        Queued  => 'fa-hourglass-half',
    );

    for my $IndexName ( sort keys %{ $SearchObject->{Config}->{RegisteredIndexes} } ) {
        my $DataEquality = $Self->DataEqualityGet(
            ClusterID => $ClusterConfig->{ClusterID},
            IndexName => $IndexName,
        );
        my $Percentage           = $DataEquality->{$IndexName}->{Percentage};
        my $LastReindexationTime = $DataEquality->{$IndexName}->{LastReindexationTime};

        my $DisplayData = $Percentage ? "$Percentage% ($LastReindexationTime)" : "Not found";
        my $Icon        = $ReindexationStatus->{$IndexName}->{Status}
            ? $IconMapping{ $ReindexationStatus->{$IndexName}->{Status} }
            : '';
        $LayoutObject->Block(
            Name => 'Index',
            Data => {
                IndexName         => $IndexName,
                DisplayData       => $DisplayData,
                ReindexingOngoing => $IsReindexingOngoing,
                Icon              => $Icon,
                EngineConnection  => $SearchObject->{ConnectObject} ? 1 : 0,
            }
        );
    }

    $LayoutObject->AddJSData(
        Key   => 'IsReindexingOngoing',
        Value => $IsReindexingOngoing,
    );

    my $SynchronizationEnabled = $CacheObject->Get(
        Type => 'ReindexingProcess',
        Key  => 'SynchronizationEnabled',
    );

    if ($IsReindexingOngoing) {
        my $Percentage = $CacheObject->Get(
            Type => 'ReindexingProcess',
            Key  => 'Percentage',
        );

        $LayoutObject->Block(
            Name => 'ProgressBar',
            Data => {
                Percentage             => $Percentage,
                InitialWidth           => $Percentage ? $Percentage * 3.8 : undef,
                SynchronizationEnabled => $SynchronizationEnabled,
                ProgressBarColor       => $Percentage
                ? $Percentage < 30
                        ? 'red'
                        : $Percentage < 50 ? 'yellow'
                    : 'green'
                : undef,
            }
        );
    }

    $Output .= $LayoutObject->Output(
        TemplateFile => "AdminSearch/Reindexation",
        Data         => {
            %Param,
            ReindexingOngoing      => $IsReindexingOngoing,
            ActiveCluster          => $ClusterConfig->{ClusterID} == $Param{ClusterID} ? 1 : 0,
            EngineConnection       => $SearchObject->{ConnectObject} ? 1 : 0,
            ActionLabel            => $IsReindexingOngoing ? 'Status' : 'Actions',
            SynchronizationEnabled => $SynchronizationEnabled,
        },
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

=head2 DataEqualityGet()

get newest information about data equality for given cluster

    my $Details = $ReindexationObject->DataEqualityGet(
        ClusterID => $ClusterID,
        IndexName => $IndexName,
    );

=cut

sub DataEqualityGet {
    my ( $Self, %Param ) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(ClusterID IndexName)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    $DBObject->Prepare(
        SQL => '
            SELECT   index_name, percentage, create_time, last_reindexation
            FROM     search_cluster_data_equality
            WHERE    cluster_id = ? AND index_name = ?
        ',
        Bind  => [ \$Param{ClusterID}, \$Param{IndexName} ],
        Limit => 1,
    );

    my $Data;
    ROW:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next ROW if $Data->{ $Row[0] };
        $Data->{ $Row[0] } = {
            Percentage           => $Row[1],
            Date                 => $Row[2],
            LastReindexationTime => $Row[3],
        };
    }

    return $Data;
}

=head2 DataEqualitySet()

set information about data equality for given cluster

    my $Details = $ReindexationObject->DataEqualitySet(
        ClusterID                        => $ClusterID,
        Indexes                          => $Indexes,
        NoPermissions                    => 1, # optional
        IndexesToClearDataEquality       => {"CustomerUser" => 1}, # optional,
        Verbose                          => 1, # optional
    );

=cut

sub DataEqualitySet {
    my ( $Self, %Param ) = @_;

    my $DBObject          = $Kernel::OM->Get('Kernel::System::DB');
    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ClusterObject     = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');

    return if !IsArrayRefWithData( $Param{Indexes} );

    my $ClusterConfig = $ClusterObject->ActiveClusterGet();

    return if $Param{ClusterID} && $ClusterConfig->{ClusterID} != $Param{ClusterID};

    my @IndexList = $SearchObject->IndexList();

    my $IndexesToClearDataEquality = $Param{IndexesToClearDataEquality} || {};

    my @ActiveIndexes;
    INDEX:
    for my $Index ( @{ $Param{Indexes} } ) {
        my $IndexRealName = $SearchObject->{Config}->{RegisteredIndexes}->{$Index};

        my $IsValid = $SearchChildObject->IndexIsValid(
            IndexName => $Index,
            RealName  => 0,
        );

        if (
            $IsValid
            && ( grep { $_ eq $IndexRealName } @IndexList )
            &&
            !$IndexesToClearDataEquality->{$Index}
            )
        {

            # index needs to pass base check to apply equality data
            # otherwise simply reset it
            my $IndexCheck = $SearchObject->IndexBaseCheck( Index => $Index );
            if ( $IndexCheck->{Success} ) {
                push @ActiveIndexes, $Index;
                next INDEX;
            }
            elsif ( $Param{Verbose} ) {
                my $Message = '';

                if ( $IndexCheck->{Message} ) {
                    $Message = "\nError: $IndexCheck->{Message}";
                }

                $LogObject->Log(
                    Priority => 'error',
                    Message => "Could not calculate index $Index data equality as it does not pass base check.$Message",
                );
            }
        }

        my $EntryExists = $Self->DataEqualityGet(
            ClusterID => $ClusterConfig->{ClusterID},
            IndexName => $Index,
        );

        if ($EntryExists) {
            return if !$DBObject->Do(
                SQL => '
                    UPDATE   search_cluster_data_equality
                    SET      percentage = 0, change_time = current_timestamp, last_reindexation = current_timestamp
                    WHERE    cluster_id = ? AND index_name = ?
                ',
                Bind => [ \$Param{ClusterID}, \$Index, ]
            );
        }
        else {
            # cannot find index on engine side, set it percentage on 0%
            return if !$DBObject->Do(
                SQL => '
                    INSERT INTO   search_cluster_data_equality (cluster_id, index_name, percentage, create_time, change_time, last_reindexation)
                    VALUES        (?, ?, 0, current_timestamp, current_timestamp, current_timestamp)
                ',
                Bind => [ \$Param{ClusterID}, \$Index, ]
            );
        }
    }

    my %QueryParams = (
        Objects     => \@ActiveIndexes,
        QueryParams => {},
        ResultType  => "COUNT",
    );

    my $EngineResponse = $SearchObject->Search(
        %QueryParams,
        NoPermissions => $Param{NoPermissions},
    ) || {};

    my $DBResponse = $SearchObject->Search(
        %QueryParams,
        UseSQLSearch  => 1,
        NoPermissions => $Param{NoPermissions},
    ) || {};

    my $IndexEqualityPercentage;
    INDEX:
    for my $Index ( sort keys %{$EngineResponse} ) {

        # if DB table is empty, prevent division by 0
        if ( !$DBResponse->{$Index} ) {
            $IndexEqualityPercentage->{$Index} = 100;
        }
        else {
            $EngineResponse->{$Index} //= 0;
            $IndexEqualityPercentage->{$Index}
                = sprintf( "%.2f", ( $EngineResponse->{$Index} * 100 ) / $DBResponse->{$Index} );
        }

        my $EntryExists = $Self->DataEqualityGet(
            ClusterID => $ClusterConfig->{ClusterID},
            IndexName => $Index,
        );

        if ($EntryExists) {
            return if !$DBObject->Do(
                SQL => '
                    UPDATE   search_cluster_data_equality
                    SET      percentage = ?, change_time = current_timestamp, last_reindexation = current_timestamp
                    WHERE    cluster_id = ? AND index_name = ?
                ',
                Bind => [ \$IndexEqualityPercentage->{$Index}, \$Param{ClusterID}, \$Index ]
            );
        }
        else {
            return if !$DBObject->Do(
                SQL => '
                    INSERT INTO   search_cluster_data_equality (cluster_id, index_name, percentage, create_time, change_time, last_reindexation)
                    VALUES        (?, ?, ?, current_timestamp, current_timestamp, current_timestamp)
                ',
                Bind => [ \$Param{ClusterID}, \$Index, \$IndexEqualityPercentage->{$Index} ]
            );
        }
    }

    if ( $Param{GetEqualityData} ) {
        my $Result = {};
        for my $Index ( sort keys %{$EngineResponse} ) {
            my $IDsCount = defined $EngineResponse->{$Index}
                ?
                $EngineResponse->{$Index}
                : 0;

            $Result->{$Index}->{CustomEngine}->{Count} = $IDsCount;
        }

        for my $Index ( sort keys %{$DBResponse} ) {
            my $IDsCount = defined $DBResponse->{$Index}
                ?
                $DBResponse->{$Index}
                : 0;

            $Result->{$Index}->{DBEngine}->{Count} = $IDsCount;
            $Result->{$Index}->{EqualityPercentage} = $IndexEqualityPercentage->{$Index};
        }

        return $Result;
    }

    return 1;
}

=head2 IndexReindexationStatus()

return state of re-indexation process if it's active

    my $IndexReindexationStatus = $ReindexationObject->IndexReindexationStatus();

=cut

sub IndexReindexationStatus {
    my ( $Self, %Param ) = @_;

    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $JSONObject  = $Kernel::OM->Get('Kernel::System::JSON');
    my $PIDObject   = $Kernel::OM->Get('Kernel::System::PID');

    my %ReindexingProcess = $PIDObject->PIDGet(
        Name => 'SearchEngineReindex',
    );

    my %ReindexingProcessAlt = $PIDObject->PIDGet(
        Name => 'SearchEngineSync',
    );

    my $IsReindexingOngoing = %ReindexingProcess || %ReindexingProcessAlt ? 1 : 0;

    my %IndexReindexationStatus = (
        IsReindexingOngoing => $IsReindexingOngoing,
    );
    return \%IndexReindexationStatus if !$IsReindexingOngoing;

    my $ReindexingQueue = $CacheObject->Get(
        Type => 'ReindexingProcess',
        Key  => 'ReindexingQueue',
    );

    $ReindexingQueue = $JSONObject->Decode(
        Data => $ReindexingQueue
    );

    my $ReindexedIndex = $CacheObject->Get(
        Type => 'ReindexingProcess',
        Key  => 'ReindexedIndex',
    );

    if ( !$ReindexingQueue && !$ReindexedIndex ) {
        my $Success = $Self->StopReindexation(
            Force => 1,
        );
        if ($Success) {
            return;
        }
        else {
            return \%IndexReindexationStatus;
        }
    }

    my $Status       = 'Done';
    my $OngoingFound = 0;
    INDEX:
    for my $Index ( sort keys %{$ReindexingQueue} ) {

        $Status = 'Queued' if $OngoingFound;

        if ( $ReindexedIndex && $Index eq $ReindexedIndex ) {
            $Status       = 'Ongoing';
            $OngoingFound = 1;
        }

        $IndexReindexationStatus{$Index} = {
            Status => $Status
        };
    }

    return \%IndexReindexationStatus;
}

=head2 StopReindexation()

stop re-indexing process

    my $Status = $ReindexationObject->StopReindexation(
        Force => 1, # optional
    );

=cut

sub StopReindexation {
    my ( $Self, %Param ) = @_;

    my $PIDObject     = $Kernel::OM->Get('Kernel::System::PID');
    my $CacheObject   = $Kernel::OM->Get('Kernel::System::Cache');
    my $SearchObject  = $Kernel::OM->Get('Kernel::System::Search');
    my $ClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');

    my %PID = $PIDObject->PIDGet(
        Name => 'SearchEngineReindex',
    );

    # check if process is registered in db
    return if !$PID{PID} && !$Param{Force};

    my $Username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);

    my $AllProcs  = find_proc();
    my $UserProcs = find_proc( user => $Username );

    my $AccessOk         = grep { $_ eq $PID{PID} } @{$UserProcs};
    my $AllUsersAccessOk = grep { $_ eq $PID{PID} } @{$AllProcs};

    return if !$AccessOk && $AllUsersAccessOk;

    my $Exists = $AccessOk || $AllUsersAccessOk ? 1 : 0;

    if ($Exists) {

        # kill reindexing process
        my $Success = kill 9, $PID{PID};
        return if !$Success;
    }

    # remove pid from db if still exists
    my $PIDDeleteSuccess = $PIDObject->PIDDelete(
        Name  => 'SearchEngineReindex',
        Force => $Param{Force},
    );
    return if !$PIDDeleteSuccess;

    my $ActiveCluster = $ClusterObject->ActiveClusterGet();

    my $ReindexingQueue = $CacheObject->Get(
        Type => 'ReindexingProcess',
        Key  => 'ReindexingQueue',
    );

    $ReindexingQueue = $JSONObject->Decode(
        Data => $ReindexingQueue
    );

    my @ReindexedIndexList = keys %{$ReindexingQueue};
    for my $Index (@ReindexedIndexList) {
        my $Result = $SearchObject->IndexRefresh(
            Index => $Index
        );
    }

    my $DataEqualitySetSuccess = $Self->DataEqualitySet(
        ClusterID     => $ActiveCluster->{ClusterID},
        Indexes       => \@ReindexedIndexList,
        NoPermissions => 1,
    );

    # cleanup cache type of reindexing process
    my $CacheDeleteSuccess = $CacheObject->CleanUp(
        Type => 'ReindexingProcess',
    );

    return 1 if $CacheDeleteSuccess && $DataEqualitySetSuccess;

    return;
}

=head2 StartReindexation()

start re-indexing process

    my $Status = $ReindexationObject->StartReindexation(
        Params => [
        '--index', 'Ticket',
        '--recreate', 'default',  # optional
        '--cluster-reinitialize', # optional
        '--check-data-equality',  # optional
        ]
    );

=cut

sub StartReindexation {
    my ( $Self, %Param ) = @_;

    my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::Search::Reindex');

    my ( $Result, $ExitCode );
    {
        local *STDOUT;
        open STDOUT, '>:utf8', \$Result;    ## no critic
        $ExitCode = $CommandObject->Execute( @{ $Param{Params} } );
    }

    return $ExitCode;
}

1;

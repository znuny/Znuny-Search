# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
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

    my $DataEquality = $Self->DataEqualityGet();
    for my $IndexName ( sort keys %{ $SearchObject->{Config}->{RegisteredIndexes} } ) {
        my $Percentage = $DataEquality->{$IndexName}->{Percentage};
        my $Date       = $DataEquality->{$IndexName}->{Date};

        my $DisplayData = $Percentage ? "$Percentage% ($Date)" : "Not found";
        my $Icon        = $ReindexationStatus->{$IndexName}{Status}
            ? $IconMapping{ $ReindexationStatus->{$IndexName}{Status} }
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

    if ($IsReindexingOngoing) {
        my $Percentage = $CacheObject->Get(
            Type => 'ReindexingProcess',
            Key  => 'Percentage',
        );

        $LayoutObject->Block(
            Name => 'ProgressBar',
            Data => {
                Percentage       => $Percentage,
                InitialWidth     => $Percentage ? $Percentage * 3.8 : undef,
                ProgressBarColor => $Percentage
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
            ReindexingOngoing => $IsReindexingOngoing,
            ActiveCluster     => $ClusterConfig->{ClusterID} == $Param{ClusterID} ? 1 : 0,
            EngineConnection  => $SearchObject->{ConnectObject} ? 1 : 0,
            ActionLabel       => $IsReindexingOngoing ? 'Status' : 'Actions',
        },
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

=head2 DataEqualityGet()

get newest information about data equality for given cluster

    my $Details = $ReindexationObject->DataEqualityGet(
        ClusterID => $ClusterID,
    );

=cut

sub DataEqualityGet {
    my ( $Self, %Param ) = @_;

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    $DBObject->Prepare(
        SQL => '
            SELECT   index_name, percentage, create_time
            FROM     search_cluster_data_equality
            ORDER BY create_time DESC
        ',
    );

    my $IndexEqualityPercentage;
    ROW:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next ROW if $IndexEqualityPercentage->{ $Row[0] };
        $IndexEqualityPercentage->{ $Row[0] } = {
            Percentage => $Row[1],
            Date       => $Row[2],
        };
    }

    return $IndexEqualityPercentage;
}

=head2 DataEqualitySet()

set information about data equality for given cluster

    my $Details = $ReindexationObject->DataEqualitySet(
        ClusterID => $ClusterID,
        Indexes => $Indexes,
        NoPermissions => 1, # optional
    );

=cut

sub DataEqualitySet {
    my ( $Self, %Param ) = @_;

    my $DBObject          = $Kernel::OM->Get('Kernel::System::DB');
    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ClusterObject     = $Kernel::OM->Get('Kernel::System::Search::Cluster');

    return if !IsArrayRefWithData( $Param{Indexes} );

    my $ClusterConfig = $ClusterObject->ActiveClusterGet();

    return if $Param{ClusterID} && $ClusterConfig->{ClusterID} != $Param{ClusterID};

    my @IndexList = $SearchObject->IndexList();

    my @ActiveIndexes;
    INDEX:
    for my $Index ( @{ $Param{Indexes} } ) {
        my $IndexRealName = $SearchObject->{Config}->{RegisteredIndexes}->{$Index};

        my $IsValid = $SearchChildObject->IndexIsValid(
            IndexName => $Index,
            RealName  => 0,
        );

        if ( $IsValid && ( grep { $_ eq $IndexRealName } @IndexList ) ) {
            push @ActiveIndexes, $Index;
            next INDEX;
        }

        # cannot find index on engine side, set it percentage on 0%
        return if !$DBObject->Do(
            SQL => '
                INSERT INTO search_cluster_data_equality (cluster_id, index_name, percentage, create_time)
                       VALUES (?, ?, 0, current_timestamp)
            ',
            Bind => [ \$Param{ClusterID}, \$Index, ]
        );
    }

    my %QueryParams = (
        Objects     => \@ActiveIndexes,
        QueryParams => {},
        ResultType  => "COUNT",
    );

    my $EngineResponse = $SearchObject->Search(
        %QueryParams,
        Fields        => [ [] ],
        NoPermissions => $Param{NoPermissions},
    ) || {};

    my $DBResponse = $SearchObject->Search(
        %QueryParams,
        UseSQLSearch  => 1,
        NoPermissions => $Param{NoPermissions},
    ) || {};

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::System::Search'],
    );

    my $IndexEqualityPercentage;
    INDEX:
    for my $Index ( sort keys %{$EngineResponse} ) {

        # if DB table is empty, prevent division by 0
        if ( !$DBResponse->{$Index} ) {
            $IndexEqualityPercentage->{$Index} = 100;
        }
        else {
            $EngineResponse->{$Index} //= 0;
            $IndexEqualityPercentage->{$Index} = ( $EngineResponse->{$Index} * 100 ) / $DBResponse->{$Index};
        }

        return if !$DBObject->Do(
            SQL => '
                INSERT INTO search_cluster_data_equality (cluster_id, index_name, percentage, create_time)
                       VALUES (?, ?, ?, current_timestamp)
            ',
            Bind => [ \$Param{ClusterID}, \$Index, \$IndexEqualityPercentage->{$Index} ]
        );
    }

    $Kernel::OM->Get('Kernel::System::Search');

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

    my $IsReindexingOngoing = %ReindexingProcess ? 1 : 0;

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

        if ( $Index eq $ReindexedIndex ) {
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

    return if ( !$AccessOk && $AllUsersAccessOk );

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

1;

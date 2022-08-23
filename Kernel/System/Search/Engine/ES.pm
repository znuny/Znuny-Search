# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Engine::ES;

use strict;
use warnings;
use Search::Elasticsearch;

use parent qw( Kernel::System::Search::Engine );

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Mapping::ES',
    'Kernel::System::Search::Cluster',
);

=head1 NAME

Kernel::System::Search::Engine::ES - Functions engine related

=head1 SYNOPSIS

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $EngineESObject = $Kernel::OM->Get('Kernel::System::Search::Engine::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 Connect()

connect to specified search engine

    my $ConnectObject = $EngineESObject->Connect(
        Config => $Config,
    );

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{Config} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need Config!"
        );
        return {
            Error => 1
        };
    }

    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');

    my $ActiveEngine = $SearchClusterObject->ActiveClusterGet();

    if ( !$ActiveEngine->{RemoteSystem} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cannot find any active search engine.",
        );
        return {
            Error => 1
        };
    }

    # try to receive information about cluster after connection.
    my $ConnectObject = Search::Elasticsearch->new(
        nodes => [
            $ActiveEngine->{RemoteSystem},
        ],
        client => '7_0::Direct',
    );

    eval {
        $ConnectObject->cluster()->health();
    };

    # If engine was not reachable than treat it like an error for further fallbacks.
    if ($@) {
        if ( $Self->{Config}->{ActiveEngine} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Connection failed for engine: $Self->{Config}->{ActiveEngine}. Message: $@",
            );
        }
        else {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Connection failed. Message: $@",
            );
        }

        return {
            Error => 1
        };
    }

    return $ConnectObject;
}

=head2 QueryExecute()

executes query for active engine with specified operation

    my $Result = $EngineESObject->QueryExecute(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        Index           => $Index,
        Operation       => $Operation,
    );

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');
    my $MappingObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES');
    my $ConnectObject = $Param{ConnectObject};

    for my $Name (qw(Query Index Operation ConnectObject)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return {
                Error    => 1,
                Fallback => {
                    Enable => 1,
                }
            };
        }
    }

    my $FunctionName = '_QueryExecute' . $Param{Operation};
    my $Result;

    eval {
        $Result = $Self->$FunctionName(
            %Param
        );
    };
    if ($@) {
        my $Engine = "Kernel::System::Search::Engine::ES";

        $LogObject->Log(
            Priority => 'error',
            Message  => "Query failed for engine: $Engine. Message: $@",
        );
        return {
            Error    => 1,
            Fallback => {
                Enable => 1,
            }
        };
    }

    return $Result;
}

=head2 DiagnosticDataGet()

executes diagnosis query for engine

    my $Result = $EngineESObject->DiagnosticDataGet(
        ConnectObject   => $ConnectObject,
    );

=cut

sub DiagnosticDataGet {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};
    return {} if !$ConnectObject;

    my $ClusterHealth = $ConnectObject->transport()->perform_request(
        method => 'GET',
        path   => "_cluster/health",
    );

    my $NodesStat = $ConnectObject->transport()->perform_request(
        method => 'GET',
        path   => "_nodes/stats",
    );

    my $IndexStat = $ConnectObject->transport()->perform_request(
        method => 'GET',
        path   => "_cat/indices",
    );

    my @Indexes = split( '\n', $IndexStat );

    my $Result = {
        Cluster => $ClusterHealth,
        Nodes   => $NodesStat,
        Indexes => \@Indexes
    };

    return $Result;
}

=head2 _QueryExecuteSearch()

executes query for active engine with specified object "Search" operation

    my $Result = $EngineESObject->_QueryExecuteSearch(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        Index           => $Index,
    );

=cut

sub _QueryExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->search(
        index => $Param{Index},
        body  => {
            %{ $Param{Query} }
        }
    );

    return $Result;
}

=head2 _QueryExecuteObjectIndexAdd()

executes query for active engine with specified object "Add" operation

    my $Result = $EngineESObject->_QueryExecuteObjectIndexAdd(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        ObjectID        => $ObjectID,
    );

=cut

sub _QueryExecuteObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_create/$Param{ObjectID}",
        body   => {
            %{ $Param{Query}->{Body} }
        }
    );

    $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_refresh",
    );

    return $Result;
}

=head2 _QueryExecuteIndexClear()

executes query for active engine with specified "IndexClear" operation

    my $Result = $EngineESObject->_QueryExecuteIndexClear(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexClear {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_delete_by_query",
        body   => {
            %{ $Param{Query}->{Body} }
        }
    );

    $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_refresh",
    );

    return $Result;
}

=head2 _QueryExecuteObjectIndexUpdate()

executes query for active engine with specified "Update" operation

    my $Result = $EngineESObject->_QueryExecuteObjectIndexUpdate(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        ObjectID        => $ObjectID,
    );

=cut

sub _QueryExecuteObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    #  TODO: Need to check integration og Age attribute
    my $Result = $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_update/$Param{ObjectID}",
        body   => {
            doc => {
                %{ $Param{Query}->{Body} }
            }
        }
    );

    $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_refresh",
    );

    return $Result;
}

=head2 _QueryExecuteObjectIndexRemove()

executes query for active engine with specified "Remove" operation

    my $Result = $EngineESObject->_QueryExecuteObjectIndexRemove(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        ObjectID        => $ObjectID,
    );

=cut

sub _QueryExecuteObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->transport()->perform_request(
        method => 'DELETE',
        path   => "/$Param{Query}->{Index}/_doc/$Param{ObjectID}",
    );

    $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_refresh",
    );

    return $Result;
}

1;

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

use Kernel::System::VariableCheck qw(IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Mapping::ES',
    'Kernel::System::Search::Cluster',
    'Kernel::System::Search::Auth::ES',
);

=head1 NAME

Kernel::System::Search::Engine::ES - elstic search engine lib

=head1 SYNOPSIS

Functions engine related.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchEngineESObject = $Kernel::OM->Get('Kernel::System::Search::Engine::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 Connect()

connect to specified search engine

    my $ConnectObject = $SearchEngineESObject->Connect(
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

    my $ClusterNodes = $SearchClusterObject->ClusterCommunicationNodeList(
        ClusterID => $ActiveEngine->{ClusterID},
        Valid     => 1,
    );

    if ( !IsArrayRefWithData($ClusterNodes) ) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Cannot find any cluster communication nodes! Connecting to Elastic search engine aborted.",
            );
        }
        return {
            Error => 1
        };
    }

    my @Nodes;
    for my $Node ( @{$ClusterNodes} ) {

        my $UserInfo = $Self->UserInfoStrgBuild(
            Login    => $Node->{Login},
            Password => $Node->{Password},
        );

        push @Nodes, {
            scheme => $Node->{Protocol} // '',
            host   => $Node->{Host}     // '',
            port   => $Node->{Port}     // '',
            path   => $Node->{Path}     // '',
            userinfo => $UserInfo,
        };
    }

    # try to receive information about cluster after connection.
    my $ConnectObject = Search::Elasticsearch->new(
        nodes  => \@Nodes,
        client => '7_0::Direct',
    );

    eval {
        $ConnectObject->cluster()->health();
    };

    # If engine was not reachable than treat it like an error for further fallbacks.
    if ($@) {
        if ( !$Param{Silent} ) {
            if ( $Param{Config}->{ActiveEngine} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Connection failed for engine: $Param{Config}->{ActiveEngine}. Message: $@",
                );
            }
            else {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Connection failed for search engine. Message: $@",
                );
            }
        }
        return {
            Error => 1
        };
    }

    return $ConnectObject;
}

=head2 QueryExecute()

executes query for active engine with specified operation

    my $Result = $SearchEngineESObject->QueryExecute(
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
                Error => 1,
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
        if ( !$Param{Silent} ) {
            my $Engine = "Kernel::System::Search::Engine::ES";

            $LogObject->Log(
                Priority => 'error',
                Message  => "Query failed for engine: $Engine. Message: $@",
            );
        }
        return {
            Error => 1,
        };
    }

    return $Result;
}

=head2 DiagnosticDataGet()

executes diagnosis query for engine

    my $Result = $SearchEngineESObject->DiagnosticDataGet(
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

=head2 CheckNodeConnection()

check connection to communication node

    my $Result = $SearchEngineESObject->CheckNodeConnection(
        Protocol   => $Protocol,
        Host       => $Host,
        Port       => $Port,
        Port       => $Port,
        Path       => $Path,
        Login      => $Login,
        Password   => $Password,
        Silent     => 1 # optional, possible: 0, 1
    );

=cut

sub CheckNodeConnection {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $UserInfo = $Self->UserInfoStrgBuild(
        Login    => $Param{Login},
        Password => $Param{Password},
    );

    my $ConnectObject = Search::Elasticsearch->new(
        sniff_request_timeout => 0.5,
        nodes                 => [
            {
                scheme => $Param{Protocol} // '',
                host   => $Param{Host}     // '',
                port   => $Param{Port}     // '',
                path   => $Param{Path}     // '',
                userinfo => $UserInfo,
            },
        ]
    );

    eval {
        $ConnectObject->cluster()->health();
    };

    # if engine was not reachable than treat it like an error for further fallbacks
    if ($@) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message =>
                    "Communication node authentication failed for node connection check. Login:$Param{Login}. Message: $@"
            );
        }
        return;
    }

    return 1;
}

=head2 UserInfoStrgBuild()

build user info string

    my $UserInfo = $SearchEngineESObject->UserInfoStrgBuild(
        Login    => 'admin',
        Password => 'admin'
    );

=cut

sub UserInfoStrgBuild {
    my ( $Self, %Param ) = @_;

    # create AuthObject
    my $SearchAuthESObject = $Kernel::OM->Get('Kernel::System::Search::Auth::ES');

    my $PwdAuth = $SearchAuthESObject->ClusterCommunicationNodeAuthPwd(
        Login  => $Param{Login},
        Pw     => $Param{Password},
        Silent => 1,
    );

    my $Login    = $PwdAuth->{Login}    // '';
    my $Password = $PwdAuth->{Password} // '';

    return "$Login:$Password";
}

=head2 _QueryExecuteSearch()

executes query for active engine with specified object "Search" operation

    my $Result = $SearchEngineESObject->_QueryExecuteSearch(
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
        },
    );

    return $Result;
}

=head2 _QueryExecuteObjectIndexAdd()

executes query for active engine with specified object "Add" operation

    my $Result = $SearchEngineESObject->_QueryExecuteObjectIndexAdd(
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

    my $Result = $SearchEngineESObject->_QueryExecuteIndexClear(
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

    my $Result = $SearchEngineESObject->_QueryExecuteObjectIndexUpdate(
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

    my $Result = $SearchEngineESObject->_QueryExecuteObjectIndexRemove(
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

=head2 _QueryExecuteIndexMappingSet()

executes query for active engine to set data mapping for specified index

    my $Result = $SearchEngineESObject->_QueryExecuteIndexMappingSet(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexMappingSet {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_mapping",
        body   => {
            %{ $Param{Query}->{Body} }
        }
    );

    return $Result;
}

=head2 _QueryExecuteIndexMappingGet()

executes query for active engine with mapping set operation

    my $Result = $SearchEngineESObject->_QueryExecuteIndexMappingGet(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexMappingGet {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->transport()->perform_request(
        method => 'GET',
        path   => "/$Param{Query}->{Index}/_mapping",
    );

    return $Result;
}

1;

# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
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

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Cluster',
    'Kernel::System::Search::Auth::ES',
    'Kernel::System::JSON',
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
                Message  => "Cannot find any cluster communication nodes! Connecting to Elasticsearch engine aborted.",
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

    return $ConnectObject if !$@;

    # If engine was not reachable than treat it like an error for further fallbacks.
    if ( !$Param{Silent} ) {
        if ( $Param{Config}->{ActiveEngine} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Connection failed for engine $Param{Config}->{ActiveEngine}. Message: $@",
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

=head2 QueryExecute()

executes query for active engine with specified operation

    my $Result = $SearchEngineESObject->QueryExecute(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        Operation       => $Operation,
    );

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');
    my $ConnectObject = $Param{ConnectObject};

    for my $Name (qw(Query Operation ConnectObject)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $FunctionName = '_QueryExecute' . $Param{Operation};
    my $Result;

    eval {
        $Result = $Self->$FunctionName(
            %Param
        );
    };

    my $Error = $@ || ( ref $Result eq 'HASH' && $Result->{errors} );

    return $Result if !$Error;

    my $ErrorMessage = $@;

    if ( !$ErrorMessage && IsHashRefWithData($Result) && $Result->{errors} && $Result->{items} ) {
        $ErrorMessage = $JSONObject->Encode(
            Data => $Result->{items},
        );
    }

    if ( !$Param{Silent} && $ErrorMessage ) {
        my $Engine = 'Kernel::System::Search::Engine::ES';

        $LogObject->Log(
            Priority => 'error',
            Message  => "Query failed for engine: $Engine. Message: $ErrorMessage",
        );
    }

    return {
        __Error  => 1,
        Response => $Result,
    };
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

    return 1 if !$@;

    # if engine was not reachable than treat it like an error for further fallbacks
    if ( !$Param{Silent} ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Communication node authentication failed for node connection check. Login:$Param{Login}. Message: $@"
        );
    }
    return;
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

=head2 QueryExecuteGeneric()

executes generic query for active engine

    my $Result = $SearchEngineESObject->QueryExecuteGeneric(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        Method          => 'POST',
        QS              => $QS,
    );

=cut

sub QueryExecuteGeneric {
    my ( $Self, %Param ) = @_;

    return $Param{ConnectObject}->transport()->perform_request(
        method => $Param{Query}->{Method},
        path   => $Param{Query}->{Path},
        body   => $Param{Query}->{Body},
        qs     => $Param{Query}->{QS},
    );
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

    return $Self->QueryExecuteGeneric(
        ConnectObject => $Param{ConnectObject},
        Query         => $Param{Query},
    );
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

    my $BulkHelper = $Param{ConnectObject}->bulk_helper(
        index => $Param{Query}->{Index},
        %{ $Param{Query}->{Refresh} },
        %{ $Param{AdditionalParameters} }
    );

    for my $Object ( @{ $Param{Query}->{Body} } ) {
        $BulkHelper->create($Object);
    }

    return $BulkHelper->flush();
}

=head2 _QueryExecuteObjectIndexSet()

executes query for active engine with specified object "Set" operation

    my $Result = $SearchEngineESObject->_QueryExecuteObjectIndexSet(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
        ObjectID        => $ObjectID,
    );

=cut

sub _QueryExecuteObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $BulkHelper = $Param{ConnectObject}->bulk_helper(
        index => $Param{Query}->{Index},
        %{ $Param{Query}->{Refresh} },
        %{ $Param{AdditionalParameters} }
    );

    for my $Object ( @{ $Param{Query}->{Body} } ) {
        $BulkHelper->index($Object);
    }

    return $BulkHelper->flush();
}

=head2 _QueryExecuteIndexAdd()

executes query for active engine with specified "IndexAdd" operation

    my $Result = $SearchEngineESObject->_QueryExecuteIndexAdd(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexAdd {
    my ( $Self, %Param ) = @_;

    return $Param{ConnectObject}->transport()->perform_request(
        method => 'PUT',
        path   => $Param{Query}->{Path},
        body   => $Param{Query}->{Body},
    );
}

=head2 _QueryExecuteIndexRemove()

executes query for active engine with specified "IndexRemove" operation

    my $Result = $SearchEngineESObject->_QueryExecuteIndexRemove(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexRemove {
    my ( $Self, %Param ) = @_;

    return $Param{ConnectObject}->transport()->perform_request(
        method => 'DELETE',
        path   => $Param{Query}->{Index},
    );
}

=head2 _QueryExecuteIndexList()

executes query for active engine with specified "IndexList" operation

    my $Result = $SearchEngineESObject->_QueryExecuteIndexList(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexList {
    my ( $Self, %Param ) = @_;

    return $Param{ConnectObject}->transport()->perform_request(
        method => 'GET',
        path   => $Param{Query}->{Path},
        qs     => {
            format => $Param{Query}->{Format},
        }
    );
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

    return $Param{ConnectObject}->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_delete_by_query",
        body   => {
            %{ $Param{Query}->{Body} }
        },
        qs => {
            %{ $Param{Query}->{Refresh} },
        }
    );
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

    my $BulkHelper = $Param{ConnectObject}->bulk_helper(
        index => $Param{Query}->{Index},
        %{ $Param{Query}->{Refresh} },
        %{ $Param{AdditionalParameters} }
    );

    for my $Object ( @{ $Param{Query}->{Body} } ) {
        $BulkHelper->update($Object);
    }

    return $BulkHelper->flush();
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

    return $Self->QueryExecuteGeneric(
        ConnectObject => $Param{ConnectObject},
        Query         => $Param{Query},
    );
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

    return $Param{ConnectObject}->transport()->perform_request(
        method => 'POST',
        path   => "/$Param{Query}->{Index}/_mapping",
        body   => {
            %{ $Param{Query}->{Body} }
        }
    );
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

    return $Param{ConnectObject}->transport()->perform_request(
        method => 'GET',
        path   => "/$Param{Query}->{Path}",
    );
}

=head2 _QueryExecuteDiagnosticDataGet()

executes diagnosis query for engine

    my $Result = $SearchEngineESObject->_QueryExecuteDiagnosticDataGet(
        ConnectObject   => $ConnectObject,
    );

=cut

sub _QueryExecuteDiagnosticDataGet {
    my ( $Self, %Param ) = @_;

    return {} if !$Param{ConnectObject};

    my $QueryResult;
    my $ReturnResult;

    for my $HealthObject (qw(Cluster Nodes Indexes)) {
        $QueryResult->{$HealthObject} = $Param{ConnectObject}->transport()->perform_request(
            method => 'GET',
            path   => $Param{Query}->{$HealthObject}->{Path},
        );
    }

    $ReturnResult->{Cluster} = $QueryResult->{Cluster};
    $ReturnResult->{Nodes}   = $QueryResult->{Nodes};

    if ( $QueryResult->{Indexes} ) {
        @{ $ReturnResult->{Indexes} } = split( '\n', $QueryResult->{Indexes} );
    }

    return $ReturnResult;
}

=head2 _QueryExecuteIndexInitialSettingsGet()

executes query for receiving initial settings for engine index

    my $Result = $SearchEngineESObject->_QueryExecuteIndexInitialSettingsGet(
        ConnectObject   => $ConnectObject,
        Query           => $Query,
    );

=cut

sub _QueryExecuteIndexInitialSettingsGet {
    my ( $Self, %Param ) = @_;

    my $ConnectObject = $Param{ConnectObject};

    my $Result = $ConnectObject->transport()->perform_request(
        method => 'GET',
        path   => $Param{Query}->{Path},
    );

    return $Result;
}

=head2 _QueryExecuteIndexRefresh()

executes query for active engine with specified index refresh operation

    my $Result = $SearchEngineESObject->_QueryExecuteSearch(
        ConnectObject    => $ConnectObject,
        Query            => $Query,
    );

=cut

sub _QueryExecuteIndexRefresh {
    my ( $Self, %Param ) = @_;

    return $Self->QueryExecuteGeneric(
        ConnectObject => $Param{ConnectObject},
        Query         => $Param{Query},
    );
}

1;

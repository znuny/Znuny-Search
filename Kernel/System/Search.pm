# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Object',
    'Kernel::System::Main',
    'Kernel::Config',
    'Kernel::System::Search::Cluster',
);

=head1 NAME

Kernel::System::Search - Search backend functions

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $Self->{Config} = $Self->ConfigGet();

    # check if engine feature is enabled
    if ( !$Self->{Config}->{Enabled} || !IsArrayRefWithData( $Self->{Config}->{RegisteredIndexes} ) ) {
        $Self->{Fallback} = 1;
        $Self->{Error}    = $Self->{Config}->{Enabled}
            ?
            { Configuration => { NoIndexRegistered => 1 } }
            : { Configuration => { Disabled => 1 } };

    }    # check if there is choosen active engine of the search
    elsif ( !$Self->{Config}->{ActiveEngine} ) {
        $Self->{Fallback} = 1;
        $Self->{Error}    = { Configuration => { ActiveEngineNotFound => 1 } };
        $LogObject->Log(
            Priority => 'error',
            Message  => "Search configuration does not specify a valid active engine!",
        );
    }
    else {
        # check base modules (mapping/engine) for selected engine
        my $ModulesCheckOk = $Self->BaseModulesCheck(
            Config => $Self->{Config},
        );

        if ( !$ModulesCheckOk ) {
            $Self->{Fallback} = 1;
            $Self->{Error}    = { BaseModules => { NotFound => 1 } };
        }
        else {
            # if there were no errors before, try connecting
            my $ConnectObject = $Self->Connect(
                Config => $Self->{Config},
            );

            if ( !$ConnectObject || $ConnectObject->{Error} ) {
                $Self->{Fallback} = 1;
                $Self->{Error}    = { Connection => { Failed => 1 } };
            }
            else {
                $Self->{ConnectObject} = $ConnectObject;
            }
        }
    }

    return $Self;
}

=head2 Search()

search for specified object data

    my $TicketSearch = $SearchObject->Search(
        Objects => ["Ticket", "TicketHistory"],
        QueryParams => {
            SLAID => 2,
            Title => 'New Title!',
            TicketID => 1,
            TicketHistoryID => 2, # this property does not exists inside index "Ticket"
                                  # and will not be applied for it as search param
        },
        ResultType => $ResultType # optional, default: 'ARRAY', possible: ARRAY,HASH,COUNT or more if extended,
        SortBy => ['TicketID', 'TicketHistoryID'],
        OrderBy => ['Down', 'Up'], # optional, possible: Down,Up
                                   # - for multiple objects: ['Down', 'Up']
                                   # - for all objects specified in "Objects" param: 'Down'
        Limit => ['', 10], # optional, possible: empty string (default value) or integer
                           # - for multiple objects:  [500, 10000, '']
                           # - for all objects specified in "Objects" param: '1000'
        Fields => [["TicketID", "SLAID"],["TicketHistoryID", "Name"]],
        # optional, possible: any valid column name
        # - for multiple objects:
        # [["TicketColumnName1", "TicketColumnName2"], ["TicketHistoryColumnName1", "TicketHistoryColumnName2"]]
        # - for only selected filtering on objects:
        # [[],["TicketHistoryColumn1", "TicketHistoryColumn2"]]
    );

    # simple call for all of single ticket history
    my $Search = $SearchObject->Search(
        Objects => ["TicketHistory"],
        QueryParams => {
            TicketID => 2,
        },
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Objects QueryParams)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    # copy standard param to avoid overwriting on standarization
    my $Params = \%Param;

    # standardize params
    $Self->SearchParamsStandardize( Param => $Params );

    # if there was an error, fallback all of the objects with given search parameters
    return $Self->Fallback( %{$Params} ) if $Self->{Fallback};

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # prepare query for engine
    my $QueryData = $SearchObject->QueryPrepare(
        %{$Params},
        Operation     => "Search",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    my @FailedIndexQuery;
    my @ValidQueries = ();

    # define valid queries
    if ( IsArrayRefWithData( $QueryData->{Queries} ) ) {
        my @FailedQueries = grep { $_->{Fallback}->{Enable} } @{ $QueryData->{Queries} };
        if ( scalar @FailedQueries > 0 ) {
            for my $Query (@FailedQueries) {
                push @FailedIndexQuery, $Query->{Object};
            }
        }
        else {
            @ValidQueries = grep { !$_->{Error} } @{ $QueryData->{Queries} };
        }
    }

    # use full fallback when no valid queries were built
    return $Self->Fallback( %{$Params} ) if ( !scalar @ValidQueries );

    my %Result;

    # execute all valid queries
    QUERY:
    for my $Query (@ValidQueries) {
        my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Query->{Object}");

        my $ResultQuery = $Self->{EngineObject}->QueryExecute(
            Query         => $Query->{Query},
            Index         => $IndexObject->{Config}->{IndexRealName},
            Operation     => 'Search',
            ConnectObject => $Self->{ConnectObject},
            Config        => $Self->{Config},
        );

        next QUERY if !$ResultQuery;

        if ( $ResultQuery->{Fallback}->{Enable} ) {
            push @FailedIndexQuery, $Query->{Object};
        }
        elsif ( $ResultQuery->{Error} ) {
            next QUERY;
        }

        my $FormattedResult = $Self->_ResultFormat(
            %{$Params},
            Result     => $ResultQuery,
            Config     => $Self->{Config},
            IndexName  => $Query->{Object},
            Operation  => "Search",
            ResultType => $Param{ResultType} || 'ARRAY',
            QueryData  => $Query,
        );

        if ( defined $FormattedResult ) {
            %Result = ( %Result, %{$FormattedResult} );
        }
    }

    if ( scalar @FailedIndexQuery > 0 ) {
        my $FallbackResult = $Self->Fallback(
            %{$Params},
            Objects => \@FailedIndexQuery,
        );
        %Result = ( %Result, %{$FallbackResult} );
    }

    return \%Result;
}

=head2 ObjectIndexAdd()

add object for specified index

    my $Success = $SearchObject->ObjectIndexAdd(
        Index => "Ticket",
        ObjectID => 1,
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index ObjectID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );

        return;
    }

    if ( $Self->{Fallback} ) {
        return;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexAdd",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    if ( !defined $QueryData->{Query} ) {
        return;
    }

    my $ResultQuery = $Self->{EngineObject}->QueryExecute(
        %Param,
        Operation     => "ObjectIndexAdd",
        Query         => $QueryData->{Query},
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    if ( $ResultQuery->{Error} )
    {
        return;
    }

    return 1;
}

=head2 ObjectIndexUpdate()

update object for specified index

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index => "Ticket",
        ObjectID => 1,
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index ObjectID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    if ( $Self->{Fallback} ) {
        return;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexUpdate",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    if ( !defined $QueryData->{Query} ) {
        return;
    }

    my $ResultQuery = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $QueryData->{Query},
        Operation     => "ObjectIndexUpdate",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    if ( $ResultQuery->{Error} )
    {
        return;
    }

    return 1;
}

=head2 ObjectIndexGet()

get object for specified index

=cut

sub ObjectIndexGet {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

remove object for specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "Ticket",
        ObjectID => 1,
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index ObjectID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    if ( $Self->{Fallback} ) {
        return;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexRemove",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    if ( !defined $QueryData->{Query} ) {
        return;
    }

    my $ResultQuery = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $QueryData->{Query},
        Operation     => "ObjectIndexRemove",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    if ( $ResultQuery->{Error} )
    {
        return;
    }

    return 1;
}

=head2 Connect()

connect for active search engine

    my $ConnectObject = $SearchObject->Connect(
        Config => $Self->{Config},
    );

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !IsHashRefWithData( $Param{Config} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need Config!"
        );
        return;
    }

    return if !$Self->{EngineObject}->can('Connect');
    my $ConnectObject = $Self->{EngineObject}->Connect(%Param);

    return $ConnectObject;
}

=head2 Disconnect()

TO-DO

=cut

sub Disconnect {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexAdd()

TO-DO

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexDrop()

TO-DO

=cut

sub IndexDrop {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexClear()

deletes the entire contents of the index

    my $Result = $SearchObject->IndexClear(
        Index => $Index,
    );

=cut

sub IndexClear {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    return if !$Param{Index};

    # check if any data exists
    my $Search = $Self->Search(
        Objects     => [ $Param{Index} ],
        QueryParams => {},
    );

    # no data exists
    if ( $Search->{ $Param{Index} } && !( IsArrayRefWithData( $Search->{ $Param{Index} } ) ) ) {
        return 1;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexClear",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $QueryData->{Query},
        Operation     => "IndexClear",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return if $Response->{Error};
    return 1;
}

=head2 ConfigGet()

get basic config for search

    $Config = $SearchObject->ConfigGet();

=cut

sub ConfigGet {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');

    my $ActiveEngineConfig = $SearchClusterObject->ActiveClusterGet();

    my $ActiveEngine          = $ActiveEngineConfig->{Engine} || '';
    my $Enabled               = $ConfigObject->Get("SearchEngine");
    my $RegisteredIndexConfig = $ConfigObject->Get("Loader::Search::$ActiveEngine");
    my $RegisteredEngines     = $Self->EngineListGet();

    my $Config = {
        Enabled => $Enabled
    };

    for my $Key ( sort keys %{$RegisteredEngines} ) {
        if ( $Key eq $ActiveEngine ) {
            $Config->{ActiveEngine} = $ActiveEngine;
        }
    }

    if ( !$Config->{ActiveEngine} && $ActiveEngine ) {
        $Config->{ActiveEngine} = 'Unregistered';
    }

    if ( IsHashRefWithData($RegisteredIndexConfig) ) {
        my @RegisteredIndex;
        for my $RegisteredIndexKey ( sort keys %{$RegisteredIndexConfig} ) {
            for my $RegisteredIndex ( @{ $RegisteredIndexConfig->{$RegisteredIndexKey} } ) {
                push @RegisteredIndex, $RegisteredIndex if !grep { $_ eq $RegisteredIndex } @RegisteredIndex;
            }
        }
        $Config->{RegisteredIndexes}
            = \@RegisteredIndex;    # key: friendly name for calls, value: name in search engine structure
    }

    return $Config;
}

=head2 BaseModulesCheck()

check for base modules validity

    my $ModulesCheckOk = $SearchObject->BaseModulesCheck(
        Config => $Self->{Config},
    );

=cut

sub BaseModulesCheck {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    return if !$Param{Config}->{ActiveEngine};

    # define base modules
    my %Modules = (
        "Mapping" => "Kernel::System::Search::Mapping::$Param{Config}->{ActiveEngine}",
        "Engine"  => "Kernel::System::Search::Engine::$Param{Config}->{ActiveEngine}",
    );

    # check if base modules exists and add them to $Self
    for my $Module ( sort keys %Modules ) {
        my $Location = $Modules{$Module};
        my $Loaded   = $MainObject->Require(
            $Location,
            Silent => 0,
        );
        if ( !$Loaded ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Module $Location is not valid!"
            );
            return;
        }
        else {
            $Self->{ $Module . "Object" } = $Kernel::OM->Get($Location);
        }
    }

    return 1;
}

=head2 DiagnosticDataGet()

get diagnostic data for active engine

    my $DiagnosisData = $SearchObject->DiagnosticDataGet();

=cut

sub DiagnosticDataGet {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    return if $Self->{Fallback} || !$Self->{MappingObject};

    my $Response = $Self->{EngineObject}->DiagnosticDataGet(
        ConnectObject => $Self->{ConnectObject},
    );

    return if !$Response;

    my $FormattedDiagnosis = $Self->{MappingObject}->DiagnosticFormat(
        Result => $Response,
    );

    return $FormattedDiagnosis;
}

=head2 Fallback()

fallback from using advanced search

    my $Result = $SearchObject->Fallback(
        Objects      => $Objects,
        QueryParams  => $QueryParams
    );

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    NEEDED:
    for my $Needed (qw(Objects QueryParams)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my %Result;
    INDEX:
    for ( my $i = 0; $i < scalar @{ $Param{Objects} }; $i++ ) {

        my $IndexName = $Param{Objects}->[$i];

        # get globally formatted fallback response
        my $Response = $SearchObject->Fallback(
            %Param,
            IndexName     => $IndexName,
            IndexCounter  => $i,
            MultipleLimit => $Param{MultipleLimit},
            OrderBy       => $Param{OrderBy}->[$i],
            SortBy        => $Param{SortBy}->[$i],
            Fields        => $Param{Fields}->[$i],
        );

        # on any error ignore response
        next INDEX if !$Response;

        # get valid result type from the response
        my $ResultType = delete $Response->{ResultType};

        # format reponse per index
        my $FormattedResult = $Self->_ResultFormat(
            Result     => $Response,
            Config     => $Self->{Config},
            IndexName  => $IndexName,
            Operation  => "Search",
            ResultType => $ResultType,
            Fallback   => 1,
        );

        # merge response into return data
        if ( defined $FormattedResult ) {
            %Result = ( %Result, %{$FormattedResult} );
        }
    }

    return \%Result;
}

=head2 SearchParamsStandardize()

globally standardize search params

    $SearchObject->SearchParamsStandardize(
        %Param,
    );

=cut

sub SearchParamsStandardize {
    my ( $Self, %Param ) = @_;

    if ( IsHashRefWithData( $Param{Param} ) ) {
        if ( IsArrayRefWithData( $Param{Param}->{Objects} ) ) {
            if ( $Param{Param}->{OrderBy} && !IsArrayRefWithData( $Param{Param}->{OrderBy} ) ) {
                my $OrderBy = $Param{Param}->{OrderBy};
                $Param{Param}->{OrderBy} = [];
                for ( my $i = 0; $i < scalar @{ $Param{Param}->{Objects} }; $i++ ) {
                    $Param{Param}->{OrderBy}->[$i] = $OrderBy;
                }
            }
            if ( ref( $Param{Param}->{Limit} ) eq 'ARRAY' ) {
                $Param{Param}->{MultipleLimit} = 1;
            }
        }
    }

    return 1;
}

=head2 EngineListGet()

get list of valid engines from XML

    my $Result = $SearchObject->EngineListGet();

=cut

sub EngineListGet {
    my ( $Self, %Param ) = @_;

    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $EngineListConfig = $ConfigObject->Get('Loader::SearchEngines');

    my %Engines;
    for my $EngineConfigKey ( sort keys %{$EngineListConfig} ) {
        for my $Engine ( sort keys %{ $EngineListConfig->{$EngineConfigKey} } ) {
            $Engines{$Engine} = $EngineListConfig->{$EngineConfigKey}->{$Engine};
        }
    }

    return \%Engines;
}

=head2 _ResultFormat()

format response data globally, then format again for index separately

    my $Result = $SearchObject->_ResultFormat(
        Config => $Self->{Config},
    );

=cut

sub _ResultFormat {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{IndexName}");
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Operation Result Config IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    # Globally standarize response.
    # Do not use it on fallback response
    # as fallback do not use advanced search engine
    # and should have response formatted globally already.
    $Param{Result} = $Self->{MappingObject}->ResultFormat(
        Result    => $Param{Result},
        Config    => $Param{Config},
        IndexName => $Param{IndexName},
        %Param,
    ) if !$Param{Fallback};    # fallback skip

    my %OperationMapping = (
        Search            => 'SearchFormat',
        ObjectIndexAdd    => 'ObjectIndexAddFormat',
        ObjectIndexGet    => 'ObjectIndexGetFormat',
        ObjectIndexRemove => 'ObjectIndexRemoveFormat',
    );

    my $OperationFormatFunction = $OperationMapping{ $Param{Operation} };

    # object separately standarize response
    my $IndexFormattedResult = $IndexObject->$OperationFormatFunction(
        GloballyFormattedResult => $Param{Result},
        %Param
    );

    return $IndexFormattedResult;
}

1;

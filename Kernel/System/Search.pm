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

Search API that allows for operating on specified engine or fallback.
Can search, add, get, update, delete indexes that are representation
of sql database in separate engine.

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
    if ( !$Self->{Config}->{Enabled} || !IsHashRefWithData( $Self->{Config}->{RegisteredIndexes} ) ) {
        $Self->{Fallback} = 1;
        $Self->{Error}    = $Self->{Config}->{Enabled}
            ?
            { Configuration => { NoIndexRegistered => 1 } }
            : { Configuration => { Disabled => 1 } };

    }    # check if there is choosen active engine of the search
    elsif ( !$Self->{Config}->{ActiveEngine} ) {
        $Self->{Fallback} = 1;
        $Self->{Error}    = { Configuration => { ActiveEngineNotFound => 1 } };
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Search configuration does not specify a valid active engine!",
            );
        }
    }
    else {
        # check base modules (mapping/engine) for selected engine
        my $ModulesCheckOk = $Self->BaseModulesCheck(
            Config => $Self->{Config},
            Silent => $Param{Silent},
        );

        if ( !$ModulesCheckOk ) {
            $Self->{Fallback} = 1;
            $Self->{Error}    = { BaseModules => { NotFound => 1 } };
        }
        else {
            # if there were no errors before, try connecting
            my $ConnectObject = $Self->Connect(
                Config => $Self->{Config},
                Silent => $Param{Silent},
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

TO-DO multiple search query param support in array (for example: TicketID => [1,2,3])

search for specified object data

    my $TicketSearch = $SearchObject->Search(
        Objects => ["Ticket", "TicketHistory"], # always pass an array of objects
        QueryParams => { # possible query parameters (fields) can be seen
                         # for each objects in
                         # Kernel::System::Search::Object::"ObjectName" module
            SLAID => 2,
            Title => 'New Title!',
            TicketID => [1,2,3,4,5],
            TicketHistoryID => 2, # this property does not exists inside index "Ticket"
                                  # and will not be applied for it as search param

            # operators can be used to define even more detailed search to use
            # on fields, but remember that not all operators can be used in all field
            # types - the default rules are specified in the module
            # Kernel::System::Search::Object::Base->DefaultConfigGet()
            # every field type can be seen in
            # Kernel::System::Search::Object::"ObjectName" module
            LockID => {
                Operator => 'IS NOT DEFINED',
            },
            StateID => {
                Operator => '>',
                Value => 2,
            }
        },
        ResultType => $ResultType, # optional, default: 'ARRAY', possible: ARRAY,HASH,COUNT or more if extended,
        SortBy => ['TicketID', 'TicketHistoryID'], # possible: any object field
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
        UseSQLSearch => 1 # define if sql search should be used
    );

    # simple call for all of single ticket history
    my $Search = $SearchObject->Search(
        Objects => ["TicketHistory"],
        QueryParams => {
            TicketID => 2,
        },
    );

    # more complex call
    my $Search = $SearchObject->Search(
        Objects => ["Ticket", "TicketHistory"],
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
            TicketHistoryID => {
                Operator => '>=', Value => 1000,
            },
        },
        ResultType => "ARRAY",
        SortBy => ['TicketID', 'TicketHistoryID'],
        OrderBy => ['Down', 'Up'],
        Limit => ['', 10],
        Fields => [["TicketID", "SLAID"],["TicketHistoryID", "Name"]],
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
    $Self->_SearchParamsStandardize( Param => $Params );

    # if there was an error, fallback all of the objects with given search parameters
    return $Self->Fallback( %{$Params} ) if $Self->{Fallback} || $Param{UseSQLSearch};

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');

    # prepare query for engine
    my $PreparedQuery = $SearchChildObject->QueryPrepare(
        %{$Params},
        Operation     => "Search",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    my @FailedIndexQuery;
    my @ValidQueries = ();

    # define valid queries
    if ( IsArrayRefWithData( $PreparedQuery->{Queries} ) ) {
        my @FailedQueries = grep { $_->{Fallback}->{Enable} } @{ $PreparedQuery->{Queries} };
        if ( scalar @FailedQueries > 0 ) {
            for my $Query (@FailedQueries) {
                push @FailedIndexQuery, $Query->{Object};
            }
        }
        else {
            @ValidQueries = grep { !$_->{Error} } @{ $PreparedQuery->{Queries} };
        }
    }

    # use full fallback when no valid queries were built
    return $Self->Fallback( %{$Params} ) if ( !scalar @ValidQueries );

    my %Result;

    # execute all valid queries
    QUERY:
    for my $Query (@ValidQueries) {
        my $Response = $Self->{EngineObject}->QueryExecute(
            Query => $Query->{Query},

            Operation     => 'Search',
            ConnectObject => $Self->{ConnectObject},
            Config        => $Self->{Config},
            Silent        => $Param{Silent},
        );

        # some object queries might fail
        # on those objects fallback will be used
        if ( !$Response ) {
            push @FailedIndexQuery, $Query->{Object};
            next QUERY;
        }

        my $FormattedResult = $Self->SearchFormat(
            %{$Params},
            Result     => $Response,
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

    # use fallback on engine failed queries
    # and merge from not failed queries response
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
        Index    => "Ticket",
        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );

        return;
    }

    return if $Self->{Fallback};

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexAdd",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Operation     => "ObjectIndexAdd",
        Query         => $PreparedQuery,
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->ObjectIndexAddFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 ObjectIndexUpdate()

update object for specified index

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index => "Ticket",
        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    return if $Self->{Fallback};

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexUpdate",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "ObjectIndexUpdate",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->ObjectIndexUpdateFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 ObjectIndexRemove()

remove object for specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "Ticket",
        ObjectID => 1, # possible: single id or ids in array
                       # for single record id: 1
                       # for multiple records ids: [1,2,3,4]
                       # or
        QueryParams => { # operators are supported
            TicketID => 1,
            StateID => { Operator = ''>', Value = '2'},
            ..,
        },
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    return if $Self->{Fallback};

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexRemove",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "ObjectIndexRemove",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->ObjectIndexRemoveFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
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

=head2 IndexAdd()

add index on the search engine side

    my $Result = $SearchObject->IndexAdd(
        IndexName => "Ticket" # this will create 'ticket' index on the engine side
    );

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexAdd",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexAdd",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->IndexAddFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexRemove()

delete index on the search engine side

    my $Result = $SearchObject->IndexRemove(
        IndexName => "Ticket" # this will delete 'ticket' index on the engine side
        # or
        IndexRealName => "ticket" # this will also delete 'ticket' index on the engine side
    );

=cut

sub IndexRemove {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexRemove",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexRemove",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->IndexRemoveFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexList()

get list of indexes in engine search for active cluster

    my @IndexList = $SearchObject->IndexList();

=cut

sub IndexList {
    my ( $Self, %Param ) = @_;

    return () if $Self->{Fallback};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexList",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return () if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexList",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    my @FormattedResponse = $Self->{MappingObject}->IndexListFormat(
        %Param,
        Result => $Response,
        Config => $Self->{Config},
    );

    return @FormattedResponse;
}

=head2 IndexInit()

initializes index by setting mapping

    my $Result = $SearchObject->IndexInit(
        Index => $Index,
    );

=cut

sub IndexInit {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Index)) {

        next NEEDED if defined $Param{$Needed};
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    # set mapping
    my $Success = $Self->IndexMappingSet(
        %Param,
        Index => $Param{Index},
    );

    if ( !$Success ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cannot initialize index: $Param{Index}, check logs for more information.",
        );
        return;
    }

    return 1;
}

=head2 IndexMappingGet()

returns actual mapping set for index

    my $Result = $SearchObject->IndexMappingGet(
        Index => $Index,
        GetAliases => 0 # optional
    );

=cut

sub IndexMappingGet {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Index)) {

        next NEEDED if defined $Param{$Needed};
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexMappingGet",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexMappingGet",
        ConnectObject => $Self->{ConnectObject},
    );

    return $Self->{MappingObject}->IndexMappingGetFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexMappingSet()

set mapping for index depending on configured fields in Object/Index module

    my $Result = $SearchObject->IndexMappingSet(
        Index => $Index,
        SetAliases => 1, # optional
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    return if $Self->{Fallback};

    NEEDED:
    for my $Needed (qw(Index)) {

        next NEEDED if defined $Param{$Needed};
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexMappingSet",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexMappingSet",
        ConnectObject => $Self->{ConnectObject},
    );

    return $Self->{MappingObject}->IndexMappingSetFormat(
        %Param,
        Result => $Response,
        Config => $Self->{Config},
    );
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

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexClear",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexClear",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->IndexClearFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 ConfigGet()

get basic config for search

    $Config = $SearchObject->ConfigGet();

=cut

sub ConfigGet {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');

    my $ActiveEngineConfig    = $SearchClusterObject->ActiveClusterGet();
    my $ActiveEngine          = $ActiveEngineConfig->{Engine} || '';
    my $Enabled               = $ConfigObject->Get("SearchEngine");
    my $RegisteredIndexConfig = $ConfigObject->Get("Loader::Search::$ActiveEngine");
    my $RegisteredEngines     = $Self->EngineListGet();

    my $Config = {
        Enabled => $Enabled,
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
        $Config->{RegisteredIndexes} = {};
        for my $RegisteredIndexes ( sort values %{$RegisteredIndexConfig} ) {
            %{ $Config->{RegisteredIndexes} } = ( %{ $Config->{RegisteredIndexes} }, %{$RegisteredIndexes} );
        }    # key: friendly name for calls, value: name in search engine structure
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
            Silent => $Param{Silent},
        );
        if ( !$Loaded ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Module $Location is not valid!"
                );
            }
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

    return if $Self->{Fallback} || !$Self->{MappingObject};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "DiagnosticDataGet",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "DiagnosticDataGet",
        ConnectObject => $Self->{ConnectObject},    #
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->DiagnosticDataGetFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
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
        my $FormattedResult = $Self->SearchFormat(
            Result     => $Response,
            Config     => $Self->{Config},
            IndexName  => $IndexName,
            Operation  => "Search",
            ResultType => $ResultType,
            Fallback   => 1,
            Silent     => $Param{Silent},
        );

        # merge response into return data
        if ( defined $FormattedResult ) {
            %Result = ( %Result, %{$FormattedResult} );
        }
    }

    return \%Result;
}

=head2 EngineListGet()

get list of valid engines from system configuration

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

=head2 SearchFormat()

format response data globally, then format again for index separately

    my $Result = $SearchObject->SearchFormat(
        Config => $Self->{Config},
    );

=cut

sub SearchFormat {
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
    $Param{Result} = $Self->{MappingObject}->SearchFormat(
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

=head2 _SearchParamsStandardize()

globally standardize search params

    my $Success = $SearchObject->_SearchParamsStandardize(
        %Param,
    );

=cut

sub _SearchParamsStandardize {
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

=head2 IndexInitialSettingsGet()

get initial configuration of index

    my $Result = $SearchObject->IndexInitialSettingsGet(
        Index => 'Index',
    );

=cut

sub IndexInitialSettingsGet {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexInitialSettingsGet",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexInitialSettingsGet",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Self->{MappingObject}->IndexInitialSettingsGetFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

1;

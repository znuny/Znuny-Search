# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

        my $MappingObjectApply = $Self->MappingObjectApply(
            Config => $Self->{Config}
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

search for specified object data

    my $TicketSearch = $SearchObject->Search(
        Objects => ["Ticket", "TicketHistory"], # always pass an array of objects
        QueryParams => { # optional
                         # possible query parameters (fields) can be seen
                         # for each objects in
                         # Kernel::System::Search::Object::"ObjectName" module
            SLAID => 2,
            Title => {
                Operator => 'FULLTEXT',

                Value => {
                    Text => "Smart subject!", # "Text" is used with fulltext search operator
                    QueryOperator => "AND"    # optional, possible: "OR", "AND" (default: "AND")
                }
                # OR
                Value => "Smart subject!"     # "AND" operator will be used for fulltext search,
                                              # and lookup for 'Smart subject!' phrase
            }
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
        AdvancedQueryParams => [ # optional, mostly supported on indexes
                                 # with first level of data structure nesting
                                 # advanced structure where an array is passed
                                 # any hashes inside are AND statements
                                 # any arrays inside are OR statements
                                 # can define multiple nesting levels
            [                    # need to start with another array
                {
                    TicketID => { # supports values that are passed in QueryParams param
                        Operator => 'IS DEFINED'
                    },
                    StateID => [1,2,3], # AND
                }
            ],
            [ # OR
                {
                    TicketID => {
                        Operator => 'IS NOT DEFINED'
                    }
                },
            ],
            [ # OR
                {
                    TicketID => {
                        Operator => '!=', Value => 0
                    }
                },
                [ # OR
                    {
                        StateID => {
                            Operator => '!=', Value => 5
                        }
                    }
                ],
            ],
        ],
        ResultType => $ResultType, # optional, default: 'ARRAY', possible: ARRAY,HASH,COUNT or more if extended,
        SortBy => ['TicketID', 'TicketHistoryID'], # possible: any object field
        OrderBy => ['Down', 'Up'],
            # optional, possible: Down,Up
            # - for multiple objects: ['Down', 'Up']
            # - for all objects specified in "Objects" param: 'Down'
        Limit => ['', 10],
            # optional, possible: empty string (default value) or integer
            # - for multiple objects:  [500, 10000, '']
            # - for all objects specified in "Objects" param: '1000'
        Fields => [["Ticket_TicketID", "Ticket_SLAID"],["TicketHistory_TicketHistoryID", "TicketHistory_Name"]],
            # optional, possible: any valid column name
            # - for multiple objects:
            # [["TicketColumnName1", "TicketColumnName2"], ["TicketHistoryColumnName1", "TicketHistoryColumnName2"]]
            # - for only selected filtering on objects:
            # [[],["TicketHistoryColumn1", "TicketHistoryColumn2"]]
            # - for getting all fields (both ways acceptable):
            # - [[][TicketHistory_*]]
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
        Fields => [["Ticket_TicketID", "Ticket_SLAID"],["TicketHistory_TicketHistoryID", "TicketHistory_Name"]],
    );

    for objects with custom search support
    check Kernel::System::Search::Object::Engine::*EngineName*::*ObjectName*

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Objects)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my %IndexResponse;

    # copy standard param to avoid overwriting on standarization
    my $Params = \%Param;

    # standardize params
    my %StandardizedObjectParams = $Self->_SearchParamsStandardize( Param => $Params );

    for my $Object ( sort keys %StandardizedObjectParams ) {
        my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Object");

        if ( exists &{"$IndexObject->{Module}::Search"} ) {

            my $MappingObject = $Self->{MappingIndexObject}->{$Object};

            my $IndexSearch = $IndexObject->Search(
                %{$Params},
                Objects => {
                    $Object => delete $StandardizedObjectParams{$Object}
                },    # pass & delete single object data
                MappingObject => $MappingObject,
                EngineObject  => $Self->{EngineObject},
                ConnectObject => $Self->{ConnectObject},
                GlobalConfig  => $Self->{Config},
            ) // {};

            %IndexResponse = ( %IndexResponse, %{$IndexSearch} );
        }
    }

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    # if there was an error, fallback all of the objects with given search parameters
    return {
        %{
            $Self->Fallback(
                %{$Params},
                Objects => \%StandardizedObjectParams,
            )
        },
        %IndexResponse
    } if $Self->{Fallback}
        || $Param{UseSQLSearch};

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # prepare query for engine
    my $PreparedQuery = $SearchChildObject->QueryPrepare(
        %{$Params},
        Objects       => \%StandardizedObjectParams,
        Operation     => "Search",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    my %FailedObjectParams;
    my @ValidQueries;

    my $ResultType = $Param{ResultType} || 'ARRAY';
    my %Result     = %IndexResponse;

    # define valid queries
    if ( IsArrayRefWithData( $PreparedQuery->{Queries} ) ) {
        my @FailedQueries = grep { $_->{Error} } @{ $PreparedQuery->{Queries} };
        if ( scalar @FailedQueries > 0 ) {
            for my $Query (@FailedQueries) {
                if ( $Query->{Fallback}->{Enable} ) {
                    $FailedObjectParams{ $Query->{Object} } = $StandardizedObjectParams{ $Query->{Object} };
                }
                else {
                    my $EmptyResult = {
                        $Query->{Object} => {
                            ObjectData => {}
                        }
                    };

                    my $FormattedEmptyResult = $Self->SearchFormat(
                        %{$Params},
                        %{ $StandardizedObjectParams{ $Query->{Object} } },
                        Result     => $EmptyResult,
                        Config     => $Self->{Config},
                        IndexName  => $Query->{Object},
                        Operation  => "Search",
                        ResultType => $ResultType,
                        QueryData  => $Query,
                    );

                    if ( IsHashRefWithData($FormattedEmptyResult) ) {
                        %Result = ( %Result, %{$FormattedEmptyResult} );
                    }
                }
            }
        }
        @ValidQueries = grep { !$_->{Error} } @{ $PreparedQuery->{Queries} };
    }

    # execute all valid queries
    QUERY:
    for my $Query (@ValidQueries) {
        my $Response = $Self->{EngineObject}->QueryExecute(
            Query         => $Query->{Query},
            Operation     => 'Search',
            ConnectObject => $Self->{ConnectObject},
            Config        => $Self->{Config},
            Silent        => $Param{Silent},
        );

        # some object queries might fail
        # on those objects fallback will be used
        if ( !$Response ) {
            $FailedObjectParams{ $Query->{Object} } = $StandardizedObjectParams{ $Query->{Object} };
            next QUERY;
        }

        my $FormattedResult = $Self->SearchFormat(
            %{$Params},
            %{ $StandardizedObjectParams{ $Query->{Object} } },
            Result     => $Response,
            Config     => $Self->{Config},
            IndexName  => $Query->{Object},
            Operation  => "Search",
            ResultType => $ResultType,
            QueryData  => $Query,
        );

        if ( IsHashRefWithData($FormattedResult) ) {
            %Result = ( %Result, %{$FormattedResult} );
        }
    }

    # use fallback on engine failed queries
    # and merge from not failed queries response
    if ( keys %FailedObjectParams > 0 ) {

        my $FallbackResult = $Self->Fallback(
            %{$Params},
            Objects => \%FailedObjectParams,
        );

        if ( IsHashRefWithData($FallbackResult) ) {
            %Result = ( %Result, %{$FallbackResult} );
        }
    }

    return \%Result;
}

=head2 ObjectIndexAdd()

add object to specified index

    my $Success = $SearchObject->ObjectIndexAdd(
        Index    => 'Ticket',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

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

    return $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}")->ObjectIndexAdd(
        %Param,
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
        EngineObject  => $Self->{EngineObject},
        ConnectObject => $Self->{ConnectObject},
    );
}

=head2 ObjectIndexSet()

set (update if exists or create if not exists) object in specified index

    my $Success = $SearchObject->ObjectIndexSet(
        Index    => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');

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

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    return $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}")->ObjectIndexSet(
        %Param,
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
        EngineObject  => $Self->{EngineObject},
        ConnectObject => $Self->{ConnectObject},
    );
}

=head2 ObjectIndexUpdate()

update object in specified index

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
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

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    return $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}")->ObjectIndexUpdate(
        %Param,
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
        EngineObject  => $Self->{EngineObject},
        ConnectObject => $Self->{ConnectObject},
    );
}

=head2 ObjectIndexRemove()

remove object from specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
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

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    return $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}")->ObjectIndexRemove(
        %Param,
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
        EngineObject  => $Self->{EngineObject},
        ConnectObject => $Self->{ConnectObject},
    );
}

=head2 Connect()

connect to active search engine

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

add index to search engine

    my $Result = $SearchObject->IndexAdd(
        IndexName => "Ticket" # this will create 'ticket' index on the engine side
    );

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{IndexName} };

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexAdd",
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexAdd",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $MappingObject->IndexAddFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexRemove()

delete index from search engine

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

    my $MappingObject;
    if ( $Param{IndexName} ) {
        $MappingObject = $Self->{MappingIndexObject}->{ $Param{IndexName} };
    }
    elsif ( $Param{IndexRealName} ) {
        $MappingObject = $Self->{MappingObject};
    }
    else {
        return;
    }

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexRemove",
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexRemove",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $MappingObject->IndexRemoveFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexList()

get list of indexes from engine search for active cluster

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

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexMappingGet",
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexMappingGet",
        ConnectObject => $Self->{ConnectObject},
    );

    return $MappingObject->IndexMappingGetFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexMappingSet()

set mapping for index depending on configured fields in Object/Index module

    my $Result = $SearchObject->IndexMappingSet(
        Index => $Index,
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

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    return $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}")->IndexMappingSet(
        %Param,
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
        EngineObject  => $Self->{EngineObject},
        ConnectObject => $Self->{ConnectObject},
    );
}

=head2 IndexClear()

deletes the entire content of the index

    my $Result = $SearchObject->IndexClear(
        Index => $Index,
        NoPermissions => $NoPermissions, # optional, skip permissions check
    );

=cut

sub IndexClear {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    return if !$Param{Index};

    # check if any data exists
    my $Search = $Self->Search(
        Objects       => [ $Param{Index} ],
        QueryParams   => {},
        NoPermissions => 1,
    );

    # no data exists
    if (
        $Search->{ $Param{Index} }
        && !( IsArrayRefWithData( $Search->{ $Param{Index} } ) )
        )
    {
        return 1;
    }

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexClear",
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexClear",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $MappingObject->IndexClearFormat(
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

    my $ActiveEngineConfig      = $SearchClusterObject->ActiveClusterGet();
    my $ActiveEngine            = $ActiveEngineConfig->{Engine} || '';
    my $SearchEngineConfig      = $ConfigObject->Get("SearchEngine");
    my $Enabled                 = IsHashRefWithData($SearchEngineConfig) && $SearchEngineConfig->{Enabled} ? 1 : 0;
    my $RegisteredIndexConfig   = $ConfigObject->Get("SearchEngine::Loader::Index::$ActiveEngine");
    my $RegisteredPluginsConfig = $ConfigObject->Get("SearchEngine::Loader::Index::${ActiveEngine}::Plugins");
    my $RegisteredEngines       = $Self->EngineListGet();

    my $Config = {
        Enabled => $Enabled,
    };

    for my $Key ( sort keys %{$RegisteredEngines} ) {
        if ( $Key eq $ActiveEngine ) {
            $Config->{ActiveEngine}     = $ActiveEngine;
            $Config->{ActiveEngineName} = $RegisteredEngines->{$Key};
        }
    }

    if ( !$Config->{ActiveEngine} && $ActiveEngine ) {
        $Config->{ActiveEngine} = 'Unregistered';
    }

    if ( IsHashRefWithData($RegisteredIndexConfig) ) {
        $Config->{RegisteredIndexes} = {};
        for my $RegisteredIndexes ( sort values %{$RegisteredIndexConfig} ) {
            %{ $Config->{RegisteredIndexes} } = ( %{ $Config->{RegisteredIndexes} }, %{$RegisteredIndexes} );
        }    # key: friendly name for calls, value: name in search engine structure
    }

    if ( IsHashRefWithData($RegisteredPluginsConfig) ) {
        $Config->{RegisteredPlugins} = {};
        for my $RegisteredPlugins ( sort values %{$RegisteredPluginsConfig} ) {
            %{ $Config->{RegisteredPlugins} } = ( %{ $Config->{RegisteredPlugins} }, %{$RegisteredPlugins} );
        }
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

        $Self->{ $Module . "Object" } = $Kernel::OM->Get($Location);
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

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    NEEDED:
    for my $Needed (qw(Objects)) {

        next NEEDED if defined $Param{$Needed};
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my %Result;
    OBJECT:
    for my $Object ( sort keys %{ $Param{Objects} } ) {
        next OBJECT if !$Object;

        # get globally formatted fallback response
        my $Response = $SearchChildObject->Fallback(
            %Param,
            IndexName => $Object,
            %{ $Param{Objects}->{$Object} },
        );

        # on any error ignore response
        next OBJECT if !IsHashRefWithData($Response);

        # get valid result type from the response
        my $ResultType = delete $Response->{ResultType};

        # format reponse per index
        my $FormattedResult = $Self->SearchFormat(
            Result     => $Response,
            Config     => $Self->{Config},
            IndexName  => $Object,
            Operation  => "Search",
            ResultType => $ResultType,
            Fallback   => 1,
            Silent     => $Param{Silent},
            %{ $Param{Objects}->{$Object} },
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
    my $EngineListConfig = $ConfigObject->Get('SearchEngine::Loader::Engine');

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
        IndexName => 'Ticket',
    );

=cut

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{IndexName}");
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(IndexName)) {
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
    if ( !$Param{Fallback} ) {
        my $MappingObject = $Self->{MappingIndexObject}->{ $Param{IndexName} };

        $Param{Result} = $MappingObject->SearchFormat(
            %Param,
        );    # fallback skip
    }

    # object separately standarize response
    my $IndexFormattedResult = $IndexObject->SearchFormat(
        GloballyFormattedResult => $Param{Result},
        %Param
    );

    return $IndexFormattedResult;
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

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexInitialSettingsGet",
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexInitialSettingsGet",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $MappingObject->IndexInitialSettingsGetFormat(
        %Param,
        Response => $Response,
        Config   => $Self->{Config},
    );
}

=head2 IndexRefresh()

refreshes index in search engine

    my $Success = $SearchObject->IndexRefresh(
        Index => $Index,
    );

=cut

sub IndexRefresh {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $MappingObject = $Self->{MappingIndexObject}->{ $Param{Index} };

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexRefresh",
        Config        => $Self->{Config},
        MappingObject => $MappingObject,
    );

    return if !$PreparedQuery;

    my $Response = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexRefresh",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    return $Response;
}

=head2 ClusterInit()

use to initialize container with their default settings

    my $Success = $SearchObject->ClusterInit(
        Force => 0 # if enabled skip a check for already initialized cluster
                   # possible: 0,1
    );

=cut

sub ClusterInit {
    my ( $Self, %Param ) = @_;

    return if $Self->{Fallback};

    my $SearchChildObject   = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');

    my $ActiveCluster = $SearchClusterObject->ActiveClusterGet();

    return if $ActiveCluster->{ClusterInitialized} && !$Param{Force};

    my %Operations;
    PLUGIN:
    for my $Plugin ( sort keys %{ $Self->{Config}->{RegisteredPlugins} } ) {
        my $ContainerInitPluginOperation
            = $Kernel::OM->Get( $Self->{Config}->{RegisteredPlugins}->{$Plugin} )->ClusterInit();

        next PLUGIN if !IsHashRefWithData($ContainerInitPluginOperation);
        $Operations{ $ContainerInitPluginOperation->{PluginName} } = $ContainerInitPluginOperation->{Status};
    }

    $SearchClusterObject->ClusterInit(
        ClusterID => $ActiveCluster->{ClusterID}
    );

    return \%Operations;
}

=head2 MappingObjectApply()

apply default or custom mapping module for each index

    my $Success = $SearchObject->MappingObjectApply();

=cut

sub MappingObjectApply {
    my ( $Self, %Param ) = @_;

    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');
    for my $RegisteredIndex ( sort keys %{ $Param{Config}->{RegisteredIndexes} } ) {
        my $Location = "Kernel::System::Search::Mapping::$Self->{Config}->{ActiveEngine}::$RegisteredIndex";

        # load object mapping module if exist
        my $Loaded = $MainObject->Require(
            $Location,
            Silent => 1,
        );

        if ($Loaded) {
            $Self->{MappingIndexObject}->{$RegisteredIndex} = $Kernel::OM->Get($Location);
        }
        else {
            $Self->{MappingIndexObject}->{$RegisteredIndex} = $Self->{MappingObject};
        }
    }

    return 1;
}

=head2 _SearchParamsStandardize()

globally standardize search params for fallback/engines

    my $Success = $SearchObject->_SearchParamsStandardize(
        %Param,
    );

=cut

sub _SearchParamsStandardize {
    my ( $Self, %Param ) = @_;

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my @Objects;
    my %ObjectData;
    if ( IsHashRefWithData( $Param{Param} ) ) {
        if ( IsArrayRefWithData( $Param{Param}->{Objects} ) ) {
            @Objects = @{ $Param{Param}->{Objects} };
            for my $Param (qw(OrderBy Limit)) {
                if ( $Param{Param}->{$Param} && !IsArrayRefWithData( $Param{Param}->{$Param} ) ) {
                    my $ParamValue = $Param{Param}->{$Param};

                    for ( my $i = 0; $i < scalar @Objects; $i++ ) {
                        $ObjectData{ $Objects[$i] }->{$Param} = $ParamValue;
                    }
                }
                elsif ( IsArrayRefWithData( $Param{Param}->{$Param} ) ) {
                    for ( my $i = 0; $i < scalar @{ $Param{Param}->{$Param} }; $i++ ) {
                        my $ParamValue = $Param{Param}->{$Param}->[$i];
                        $ObjectData{ $Objects[$i] }->{$Param} = $ParamValue;
                    }
                }
            }
        }
    }

    OBJECT:
    for ( my $i = 0; $i < scalar @Objects; $i++ ) {
        my $ObjectName = $Objects[$i];

        my %ValidFields = $SearchChildObject->ValidFieldsPrepare(
            Fields      => $Param{Param}->{Fields}->[$i],
            Object      => $ObjectName,
            QueryParams => $Param{Param}->{QueryParams},
            %Param,
        );

        $ObjectData{ $Param{Param}->{Objects}->[$i] }->{Fields} = \%ValidFields // {};

        for my $Param (qw (SortBy)) {
            $ObjectData{ $Param{Param}->{Objects}->[$i] }->{$Param} =
                $Param{Param}->{$Param}->[$i];
        }
    }

    return %ObjectData;
}

1;

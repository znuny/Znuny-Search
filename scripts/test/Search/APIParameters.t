# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));
use Kernel::System::VariableCheck qw(:all);

# this test is not supposed to be executed in gitlab ci

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);

my $StateObject    = $Kernel::OM->Get('Kernel::System::State');
my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
my $HelperObject   = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $SearchObject   = $Kernel::OM->Get('Kernel::System::Search');
my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
my $UserObject     = $Kernel::OM->Get('Kernel::System::User');
my $TypeObject     = $Kernel::OM->Get('Kernel::System::Type');
my $QueueObject    = $Kernel::OM->Get('Kernel::System::Queue');

# just for gitlab pipeline to pass this test
if ( !$SearchObject->{ConnectObject} ) {
    return 1;
}

my $StartQueuedIndexation = sub {
    my ( $Self, %Param ) = @_;

    my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::Search::ES::IndexQueueDataProcess');

    my ( $Result, $ExitCode );
    {
        local *STDOUT;
        open STDOUT, '>:utf8', \$Result;    ## no critic
        $ExitCode = $CommandObject->Execute();
    }

    return $ExitCode;
};

# check if there is connection with search engine
$Self->True(
    $SearchObject->{ConnectObject},
    "Connection to engine - Exists"
);

# enable type/responsible
$ConfigObject->Set(
    Key   => 'Ticket::Type',
    Value => 1,
);

$ConfigObject->Set(
    Key   => 'Ticket::Responsible',
    Value => 1,
);

my $RegisteredIndexes    = $SearchObject->{Config}->{RegisteredIndexes};
my $AnyIndexIsRegistered = IsHashRefWithData($RegisteredIndexes);

$Self->True(
    $AnyIndexIsRegistered,
    "Any index is registered for testing check."
);

my %IndexesToTest = (
    Ticket        => 'ticket',
    TicketHistory => 'ticket_history',
);

my %RegisteredIndexesToTest;
for my $IndexName ( sort keys %IndexesToTest ) {
    $RegisteredIndexesToTest{$IndexName} = $RegisteredIndexes->{$IndexName} if $RegisteredIndexes->{$IndexName};

    $Self->True(
        $RegisteredIndexes->{$IndexName},
        "Checking if index $IndexName is registered."
    );
}

my %RegisteredIndexesToTestReversed = reverse %RegisteredIndexesToTest;

# check which indexes are already created
my @IndexList = $SearchObject->IndexList();
my %AlreadyExistingIndexes;

if ( scalar @IndexList ) {
    %AlreadyExistingIndexes
        = map { $RegisteredIndexesToTestReversed{$_} => $_ } grep { $RegisteredIndexesToTestReversed{$_} } @IndexList;
}

# remove already created indexes
for my $IndexName ( sort keys %AlreadyExistingIndexes ) {
    my $Result = $SearchObject->IndexRemove(
        IndexName => $IndexName,
    );

    $Self->True(
        $Result,
        "Removing index: $IndexName before actual testing as it already exists on the custom engine side."
    );
}

for my $IndexName ( sort keys %IndexesToTest ) {
    my $AddSuccess = $SearchObject->IndexAdd(
        IndexName => $IndexName,
    );

    $Self->True(
        $AddSuccess,
        "Adding index: $IndexName."
    );

    # initialize index
    my $InitSuccess = $SearchObject->IndexInit(
        Index => $IndexName,
    );

    $Self->True(
        $InitSuccess,
        "Initializing index: $IndexName."
    );
}

my $TestEntities = {
    Basic => {
        User => {
            ID => 1,
        },
        Queue => {
            Name      => 'some-queue',
            GroupID   => 1,
            LookupKey => 'QueueID',
        },
        Type => {
            Name      => 'some-type',
            LookupKey => 'TypeID',
        },
        Owner => {
            Login     => 'some-owner',
            LookupKey => 'OwnerID',
        },
        Priority => {
            Name      => 'some-priority',
            LookupKey => 'PriorityID',
        },
        State => {
            Name      => 'some-state',
            LookupKey => 'StateID',
        },
    }
};

my $StateID = $StateObject->StateAdd(
    Name    => $TestEntities->{Basic}->{State}->{Name},
    Comment => 'some comment',
    ValidID => 1,
    TypeID  => 1,
    UserID  => $TestEntities->{Basic}->{User}->{ID},
);

$Self->True(
    $StateID,
    "Basic State (id: $StateID) created/exists, sql.",
);

my $PrioID = $PriorityObject->PriorityAdd(
    Name    => $TestEntities->{Basic}->{Priority}->{Name},
    ValidID => 1,
    UserID  => $TestEntities->{Basic}->{User}->{ID},
);

$Self->True(
    $PrioID,
    "Basic Priority (id: $PrioID) created/exists, sql.",
);

# add example user
my $UserOwnerID = $UserObject->UserAdd(
    UserFirstname => 'Huber',
    UserLastname  => 'Manfred',
    UserLogin     => $TestEntities->{Basic}->{Owner}->{Login},
    UserEmail     => 'email@mail.com',
    ValidID       => 1,
    ChangeUserID  => 1,
);

$Self->True(
    $UserOwnerID,
    "Basic Owner (id: $UserOwnerID) created/exists, sql.",
);

my $TypeID = $TypeObject->TypeAdd(
    Name    => $TestEntities->{Basic}->{Type}->{Name},
    ValidID => 1,
    UserID  => $TestEntities->{Basic}->{User}->{ID},
);

$Self->True(
    $TypeID,
    "Basic Type (id: $TypeID) created/exists, sql.",
);

my @QueueIDs;
my @TicketQueueIDs;

for my $Counter ( 1 .. 3 ) {
    my $QueueID = $QueueObject->QueueAdd(
        Name            => $TestEntities->{Basic}->{Queue}->{Name} . $Counter,
        ValidID         => 1,
        GroupID         => $TestEntities->{Basic}->{Queue}->{GroupID},
        SystemAddressID => 1,
        SalutationID    => 1,
        SignatureID     => 1,
        Comment         => 'Some comment',
        UserID          => $TestEntities->{Basic}->{User}->{ID},
    );

    $Self->True(
        $QueueID,
        "Basic Queue (id: $QueueID) created/exists, sql.",
    );

    push @QueueIDs, $QueueID;

    # create ticket
    my $TicketID = $HelperObject->TicketCreate(
        QueueID    => $QueueID,
        OwnerID    => $UserOwnerID,
        StateID    => $StateID,
        PriorityID => $PrioID,
        TypeID     => $TypeID,
    );

    push @TicketQueueIDs, $TicketID;
}

my %TicketAllQueueBasedParams = (
    Objects     => ['Ticket'],
    QueryParams => {
        UserID  => 1,
        QueueID => \@QueueIDs,
    },
    ResultType => 'ARRAY',
);

my $QueuesStrg = join ',', @QueueIDs;

my %ExpectedBaseTicketHistoryEntry = (
    TicketID   => $TicketQueueIDs[0],
    TypeID     => $TypeID,
    OwnerID    => $UserOwnerID,
    StateID    => $StateID,
    TypeID     => $TypeID,
    PriorityID => $PrioID,
);

my %Tests = (
    Ticket => [
        {
            Name       => "(Custom engine) Ticket search queues descending (QueueIDs: $QueuesStrg)",
            Parameters => {
                %TicketAllQueueBasedParams,
                SortBy  => ['QueueID'],
                OrderBy => ['Down'],
                Fields  => [ [ 'Ticket_QueueID', 'Ticket_TicketID' ] ],
            },
            ExpectedResult => {
                Ticket => [
                    {
                        QueueID  => $QueueIDs[2],
                        TicketID => $TicketQueueIDs[2],
                    },
                    {
                        QueueID  => $QueueIDs[1],
                        TicketID => $TicketQueueIDs[1],
                    },
                    {
                        QueueID  => $QueueIDs[0],
                        TicketID => $TicketQueueIDs[0],
                    },
                ],
            },
        },
        {
            Name       => "(Custom engine) Ticket search queues ascending (QueueIDs: $QueuesStrg)",
            Parameters => {
                %TicketAllQueueBasedParams,
                SortBy  => ['QueueID'],
                OrderBy => ['Up'],
                Fields  => [ [ 'Ticket_QueueID', 'Ticket_TicketID' ], ],
            },
            ExpectedResult => {
                Ticket => [
                    {
                        QueueID  => $QueueIDs[0],
                        TicketID => $TicketQueueIDs[0],
                    },
                    {
                        QueueID  => $QueueIDs[1],
                        TicketID => $TicketQueueIDs[1],
                    },
                    {
                        QueueID  => $QueueIDs[2],
                        TicketID => $TicketQueueIDs[2],
                    },
                ],
            },
        },
        {
            Name       => "(Custom engine) Ticket search queues ascending (QueueIDs: $QueuesStrg) with \"Limit\" of 2",
            Parameters => {
                %TicketAllQueueBasedParams,
                SortBy  => ['QueueID'],
                OrderBy => ['Up'],
                Fields  => [ [ 'Ticket_QueueID', 'Ticket_TicketID' ], ],
                Limit   => 2,
            },
            ExpectedResult => {
                Ticket => [
                    {
                        QueueID  => $QueueIDs[0],
                        TicketID => $TicketQueueIDs[0],
                    },
                    {
                        QueueID  => $QueueIDs[1],
                        TicketID => $TicketQueueIDs[1],
                    },
                ],
            },
        },
        {
            Name       => "(Custom engine) Ticket search with invalid field and result: ARRAY",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID => 1,
                },
                Fields     => [ ['Ticket_InvalidColumn'] ],
                ResultType => 'ARRAY',
            },
            ExpectedResult => {
                Ticket => [],
            },
        },
        {
            Name       => "(Custom engine) Ticket search with invalid field and result: HASH",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID => 1,
                },
                Fields     => [ ['Ticket_InvalidColumn'] ],
                ResultType => 'HASH',
            },
            ExpectedResult => {
                Ticket => {},
            },
        },
        {
            Name       => "(Custom engine) Ticket search with invalid field and result: HASH_SIMPLE",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID => 1,
                },
                Fields     => [ ['Ticket_InvalidColumn'] ],
                ResultType => 'HASH_SIMPLE',
            },
            ExpectedResult => {
                Ticket => {},
            },
        },
        {
            Name       => "(Custom engine) Ticket search with invalid field and result: ARRAY_SIMPLE",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID => 1,
                },
                Fields     => [ ['Ticket_InvalidColumn'] ],
                ResultType => 'ARRAY_SIMPLE',
            },
            ExpectedResult => {
                Ticket => [],
            },
        },
        {
            Name       => "(Custom engine) Ticket search with invalid field and result: COUNT",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID => 1,
                },
                Fields     => [ ['Ticket_InvalidColumn'] ],
                ResultType => 'COUNT',
            },
            ExpectedResult => {
                Ticket => 3,
            },
        },
        {
            Name       => "(Custom engine) Ticket search with one invalid/one valid field and result: ARRAY",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID => 1,
                },
                SortBy     => ['TicketID'],
                OrderBy    => ['Up'],
                Fields     => [ [ 'Ticket_InvalidColumn', 'Ticket_TicketID' ] ],
                ResultType => 'ARRAY',
            },
            ExpectedResult => {
                Ticket => [
                    {
                        TicketID => $TicketQueueIDs[0]
                    },
                    {
                        TicketID => $TicketQueueIDs[1]
                    },
                    {
                        TicketID => $TicketQueueIDs[2]
                    },
                ]
            },
        },
        {
            Name       => "(Custom engine) Ticket search with offset: 1, limit 1. ",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID   => 1,
                    TicketID => \@TicketQueueIDs,
                },
                SortBy     => ['TicketID'],
                OrderBy    => ['Up'],
                Fields     => [ ['Ticket_TicketID'] ],
                ResultType => 'ARRAY',
                Offset     => 1,
                Limit      => 1,
            },
            ExpectedResult => {
                Ticket => [
                    {
                        TicketID => $TicketQueueIDs[1]
                    },
                ]
            },
        },
        {
            Name       => "(Custom engine) Ticket search with RetrieveEngineData parameter: TotalHits set to 'All'. ",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID   => 1,
                    TicketID => \@TicketQueueIDs,
                },
                SortBy             => ['TicketID'],
                OrderBy            => ['Up'],
                Fields             => [ ['Ticket_TicketID'] ],
                ResultType         => 'ARRAY',
                RetrieveEngineData => {
                    TotalHits => 'All',
                },
            },
            ExpectedResult => {
                Ticket => {
                    EngineData => {
                        TotalHits         => 3,
                        TotalHitsRelation => 'eq',
                    },
                    ObjectData => [
                        {
                            TicketID => $TicketQueueIDs[0]
                        },
                        {
                            TicketID => $TicketQueueIDs[1]
                        },
                        {
                            TicketID => $TicketQueueIDs[2]
                        },
                    ]
                }
            },
        },
        {
            Name       => "(Custom engine) Ticket search with RetrieveEngineData parameter: TotalHits set to 2. ",
            Parameters => {
                Objects     => ['Ticket'],
                QueryParams => {
                    UserID   => 1,
                    TicketID => \@TicketQueueIDs,
                },
                SortBy             => ['TicketID'],
                OrderBy            => ['Up'],
                Fields             => [ ['Ticket_TicketID'] ],
                ResultType         => 'ARRAY',
                RetrieveEngineData => {
                    TotalHits => 2,
                },
            },
            ExpectedResult => {
                Ticket => {
                    EngineData => {
                        TotalHits         => 2,
                        TotalHitsRelation => 'gte',
                    },
                    ObjectData => [
                        {
                            TicketID => $TicketQueueIDs[0]
                        },
                        {
                            TicketID => $TicketQueueIDs[1]
                        },
                        {
                            TicketID => $TicketQueueIDs[2]
                        },
                    ]
                }
            },
        },
    ],
    TicketHistory => [
        {
            Name       => '(Custom engine) Ticket with TicketHistory search by TicketID',
            Parameters => {
                Objects     => [ 'TicketHistory', 'Ticket' ],
                QueryParams => {
                    TicketID => $TicketQueueIDs[0],
                    UserID   => 1,
                },
                ResultType => 'ARRAY',
                SortBy     => [ 'TicketID', 'TicketID' ],
                OrderBy    => [ 'Down', 'Down' ],
                Fields     => [
                    [
                        'TicketHistory_TicketID',
                        'TicketHistory_TypeID',
                        'TicketHistory_StateID',
                        'TicketHistory_PriorityID',
                        'TicketHistory_OwnerID'
                    ],
                    ['Ticket_TicketID']
                ],
            },
            ExpectedResult => {
                Ticket => [
                    {
                        TicketID => $TicketQueueIDs[0]
                    }
                ],
                TicketHistory => [
                    \%ExpectedBaseTicketHistoryEntry,
                    \%ExpectedBaseTicketHistoryEntry,
                    \%ExpectedBaseTicketHistoryEntry,
                    \%ExpectedBaseTicketHistoryEntry,
                    \%ExpectedBaseTicketHistoryEntry,
                ]
            },
        },
        {
            Name       => '(SQL engine) TicketHistory sql search by TicketID limited to 2 entries',
            Parameters => {
                Objects     => ['TicketHistory'],
                QueryParams => {
                    TicketID => $TicketQueueIDs[0],
                    UserID   => 1,
                },
                ResultType   => 'ARRAY',
                SortBy       => ['TicketID'],
                OrderBy      => ['Down'],
                Limit        => 2,
                UseSQLSearch => 1,
                Fields       => [
                    [
                        'TicketHistory_TicketID',
                        'TicketHistory_TypeID',
                        'TicketHistory_StateID',
                        'TicketHistory_PriorityID',
                        'TicketHistory_OwnerID'
                    ]
                ],
            },
            ExpectedResult => {
                TicketHistory => [
                    \%ExpectedBaseTicketHistoryEntry,
                    \%ExpectedBaseTicketHistoryEntry,
                ]
            },
        }
    ]
);

$StartQueuedIndexation->();

for my $Index ( sort keys %Tests ) {

    # refresh  index
    $SearchObject->IndexRefresh(
        Index => $Index,
    );

    for my $Test ( @{ $Tests{$Index} } ) {
        my $Name           = $Test->{Name};
        my $Parameters     = $Test->{Parameters};
        my $ExpectedResult = $Test->{ExpectedResult};

        # search in elasticsearch
        my $Data = $SearchObject->Search(
            %{$Parameters}
        );

        $Self->IsDeeply(
            $Data,
            $ExpectedResult,
            "(Search) Response check - $Name",
        );
    }
}

1;

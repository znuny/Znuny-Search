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

my $TicketObject      = $Kernel::OM->Get('Kernel::System::Ticket');
my $HelperObject      = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
my $DBObject          = $Kernel::OM->Get('Kernel::System::DB');
my $JSONObject        = $Kernel::OM->Get('Kernel::System::JSON');

# just for gitlab pipeline to pass this test
if ( !$SearchObject->{ConnectObject} ) {
    return 1;
}

# check if there is connection with search engine
$Self->True(
    $SearchObject->{ConnectObject},
    "Connection to engine - Exists"
);

my $RegisteredIndexes = $SearchObject->{Config}->{RegisteredIndexes};
for my $Index ( sort keys %{$RegisteredIndexes} ) {
    my $QueueDeleteSuccess = $SearchChildObject->IndexObjectQueueDelete(
        Index => $Index,
    );

    $Self->True(
        $QueueDeleteSuccess,
        "Deleted queue for index: $Index, search engine."
    );
}

# create test objects for indexes: Ticket, Article, TicketHistory
for my $Counter ( 1 .. 5 ) {
    my $TicketID = $HelperObject->TicketCreate();

    $Self->True(
        $TicketID,
        "Ticket create check."
    );

    push @{ $Self->{Test1}->{Ticket}->{ExpectedResult}->{ObjectID}->{$TicketID} }, {
        Operation => 'ObjectIndexAdd',
    };

    my $ArticleID = $HelperObject->ArticleCreate(
        TicketID => $TicketID,
    );

    push @{ $Self->{Test1}->{Article}->{ExpectedResult}->{ObjectID}->{$ArticleID} }, {
        Operation => 'ObjectIndexAdd',
        Data      => undef,
    };

    $DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_history WHERE ticket_id = ?',
        Bind => [ \$TicketID ],
    );

    while ( my @DataFetch = $DBObject->FetchrowArray() ) {
        push @{ $Self->{Test1}->{TicketHistory}->{ExpectedResult}->{ObjectID}->{ $DataFetch[0] } }, {
            Operation => 'ObjectIndexAdd',
            Data      => undef,
        };
    }
}

# for each test index check if queue is filled with recently added objects
for my $Index (qw(Ticket Article TicketHistory)) {
    my $Data = $SearchChildObject->IndexObjectQueueGet(
        Index => $Index,
    );

    for my $ObjectID ( sort keys %{ $Self->{Test1}->{$Index}->{ExpectedResult}->{ObjectID} } ) {
        my $ExpectedResult = $Self->{Test1}->{$Index}->{ExpectedResult}->{ObjectID}->{$ObjectID};
        my $Result         = $Data->{ObjectID}->{$ObjectID};
        my @IDsToCheck;

        # delete ID as it auto-increments and does not need any check
        if ( IsArrayRefWithData($Result) ) {
            for my $Value ( @{$Result} ) {
                push @IDsToCheck, delete $Value->{ID};
            }
        }

        $Self->IsDeeply(
            $Result,
            $ExpectedResult,
            "(Data queue: ObjectIndexAdd) Check queued data for index: $Index, ObjectID: $ObjectID.",
        );

        # save ids of added queue entries for further testing
        push @{ $Self->{Test1}->{$Index}->{IDsToUpdate} }, @IDsToCheck;

        # test "IndexObjectQueueExists" function to search by ID, then by ObjectID parameters
        for my $IDCheck (@IDsToCheck) {
            my $ID = $SearchChildObject->IndexObjectQueueExists(
                ID => $IDCheck,
            );

            $Self->True(
                $ID,
                "(Data queue) Check queued data if exists - $Index, ID: $IDCheck, ObjectID: $ObjectID",
            );
        }

        my $ID = $SearchChildObject->IndexObjectQueueExists(
            ObjectID => $ObjectID,
            Index    => $Index,
        );

        $Self->True(
            $ID,
            "(Data queue) Check queued data if exists based on ObjectID parameter - $Index, ObjectID: $ObjectID",
        );
    }
}

# define update data to be replaced with recent queued data
my %TestDataToUpdate = (
    Data => {
        SomeData => {
            EvenMoreData => 1,
        }
    },
    QueryParams => {
        QueueID         => 1,
        SomeOtherColumn => {
            Operator => '=',
            Value    => 'something',
        }
    },
    Operation => 'ObjectIndexDelete',
    Context   => 'some-context',
);

my %TestDataToUpdateExpected = %TestDataToUpdate;

# get function will retrieve only important data for object id
for my $Column (qw (Context QueryParams)) {
    delete $TestDataToUpdateExpected{$Column};
}

for my $Index (qw(Ticket Article TicketHistory)) {
    for my $IDCheck ( @{ $Self->{Test1}->{$Index}->{IDsToUpdate} } ) {
        my $Success = $SearchChildObject->IndexObjectQueueUpdate(
            ID => $IDCheck,
            %TestDataToUpdate,
        );

        $Self->True(
            $Success,
            "(Data queue) Check queued data update success - Index: $Index, ID: $IDCheck",
        );
    }

    my $Data = $SearchChildObject->IndexObjectQueueGet(
        Index => $Index,
    );

    UPDATEDID:
    for my $IDCheck ( @{ $Self->{Test1}->{$Index}->{IDsToUpdate} } ) {
        for my $ObjectID ( sort keys %{ $Data->{ObjectID} } ) {
            if (
                $Data->{ObjectID}->{$ObjectID}
                &&
                $Data->{ObjectID}->{$ObjectID}->[0]->{ID} &&
                $Data->{ObjectID}->{$ObjectID}->[0]->{ID} eq $IDCheck
                )
            {
                my $DataToCompare = $Data->{ObjectID}->{$ObjectID}->[0];
                delete $DataToCompare->{ID};

                $Self->IsDeeply(
                    $DataToCompare,
                    \%TestDataToUpdateExpected,
                    "(Data queue) Check queued, updated data validity for index: $Index, ObjectID: $ObjectID.",
                );
                next UPDATEDID;
            }
        }
        $Self->True(
            0,
            "(Data queue) Updated queue data was not found - $Index, ID: $IDCheck.",
        );
    }
}

# delete by object id
for my $Index (qw(Ticket Article)) {

    for my $ObjectID ( sort keys %{ $Self->{Test1}->{$Index}->{ExpectedResult}->{ObjectID} } ) {
        my $Success = $SearchChildObject->IndexObjectQueueDelete(
            ObjectID => $ObjectID,
            Index    => $Index,
        );

        my $Exists = $SearchChildObject->IndexObjectQueueExists(
            ObjectID => $ObjectID,
            Index    => $Index,
        );

        $Self->True(
            $Success && !$Exists,
            "(Data queue) Check queued data delete success - Index: $Index, ObjectID: $ObjectID",
        );
    }
}

for ( 1 .. 5 ) {
    my $TicketID = $HelperObject->TicketCreate();
    push @{ $Self->{Test2}->{Ticket}->{CreatedTicketIDs} }, $TicketID;
}

my $TestData = {
    'some-data' => 1
};

$Self->{Test2}->{Ticket}->{ExpectedResult} = {
    LastOrder   => '1',
    QueryParams => {
        ObjectIndexAdd_MultipleTicketCreated_Test2 => [
            {
                Order       => '1',
                QueryParams => {
                    TicketID => $Self->{Test2}->{Ticket}->{CreatedTicketIDs},
                },
                Data      => $TestData,
                Operation => 'ObjectIndexAdd'
            }
        ]
    }
};

# delete queue to manually fill it
my $Success = $SearchChildObject->IndexObjectQueueDelete(
    Index => 'Ticket',
);

my $Data = $SearchChildObject->IndexObjectQueueGet(
    Index => 'Ticket',
);

$Self->False(
    $Data,
    "(Data queue) Check deletion of all data queue for index: Ticket.",
);

# test queue rules
$SearchChildObject->IndexObjectQueueEntry(
    Index => 'Ticket',
    Value => {
        Operation   => 'ObjectIndexAdd',
        QueryParams => {
            TicketID => $Self->{Test2}->{Ticket}->{CreatedTicketIDs},
        },
        Context => "ObjectIndexAdd_MultipleTicketCreated_Test2",
        Data    => $TestData,
    },
);

$Data = $SearchChildObject->IndexObjectQueueGet(
    Index => 'Ticket',
);

# don't need to test id column validity
delete $Data->{QueryParams}->{ObjectIndexAdd_MultipleTicketCreated_Test2}->[0]->{ID};

$Self->IsDeeply(
    $Data,
    $Self->{Test2}->{Ticket}->{ExpectedResult},
    "(Data queue) Add indexing queue based on query params and context.",
);

1;

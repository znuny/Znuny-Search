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

my $SearchObject       = $Kernel::OM->Get('Kernel::System::Search');
my $HelperObject       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ArticleObject      = $Kernel::OM->Get('Kernel::System::Ticket::Article');
my $SysConfigObject    = $Kernel::OM->Get('Kernel::System::SysConfig');
my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

# set customer user module to Elasticsearch
$CustomerUserObject->{CustomerUser}->{CustomerUserMap}->{Module} = 'Kernel::System::CustomerUser::Elasticsearch';

# just for gitlab pipeline to pass this test
if ( !$SearchObject->{ConnectObject} ) {
    return 1;
}

# check if there is connection with search engine
$Self->True(
    $SearchObject->{ConnectObject},
    "Connection to engine - Exists"
);

my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# delete most objects related to the indexes
for my $SQLTable (
    qw(
    time_accounting mail_queue
    article_search_index article_data_mime
    article_data_mime_plain article_flag
    ticket_history ticket_flag article_data_mime_attachment
    article_data_mime_send_error article ticket dynamic_field_value
    dynamic_field customer_user
    )
    )
{
    $DBObject->Do(
        SQL => "DELETE FROM $SQLTable",
    );
}

my %IndexesToTest = (
    Ticket        => 'ticket',
    TicketHistory => 'ticket_history',
    Article       => 'article',
    DynamicField  => 'dynamic_field',
    CustomerUser  => 'customer_user',
);

# register test indexes in sysconfig
$ConfigObject->Set(
    Key   => "SearchEngine::Loader::Index::$SearchObject->{ActiveEngine}",
    Value => {
        %IndexesToTest,
    },
);

# disable troublesome events
for my $SettingName (
    "CustomerUser::EventModulePost###000-DynamicFieldValue-ObjectIndex",
    "CustomerUser::EventModulePost###000-CustomerUser-ObjectIndex",
    "Daemon::SchedulerCronTaskManager::Task###$SearchObject->{Config}->{ActiveEngine}-IndexQueueDataProcess",
    )
{
    my $ExclusiveLockGUID = $SysConfigObject->SettingLock(
        Name   => $SettingName,
        Force  => 1,
        UserID => 1,
    );

    my %Result = $SysConfigObject->SettingUpdate(
        Name              => $SettingName,
        IsValid           => 0,
        UserID            => 1,
        NoValidation      => 1,
        ExclusiveLockGUID => $ExclusiveLockGUID,
    );
}

# renew search object as config was changed
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Kernel::System::Search',
    ],
);

$SearchObject = $Kernel::OM->Get('Kernel::System::Search');
my $ReindexationObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');

my $RegisteredIndexes    = $SearchObject->{Config}->{RegisteredIndexes};
my $AnyIndexIsRegistered = IsHashRefWithData($RegisteredIndexes);

$Self->True(
    $AnyIndexIsRegistered,
    "Any index is registered for testing check."
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

my %ExpectedSQLDataCount = (
    Article       => 10,
    Ticket        => 10,
    TicketHistory => 60,    # automatic ticket_history
                            # creation should fill 60 entries
    DynamicField  => 10,
    CustomerUser  => 10,
);

# create 10 test objects for each index
for my $Index ( reverse sort keys %IndexesToTest ) {

    # ticket will create entries in table ticket and ticket_history
    # it will contain one article
    if ( $Index eq 'Ticket' ) {
        for ( 1 .. 10 ) {
            my $TicketID  = $HelperObject->TicketCreate();
            my $ArticleID = $HelperObject->ArticleCreate(
                TicketID => $TicketID,
            );
            push @{ $Self->{CreatedObjects}->{Ticket}->{ID} },  $TicketID;
            push @{ $Self->{CreatedObjects}->{Article}->{ID} }, $ArticleID;

            $DBObject->Prepare(
                SQL  => 'SELECT id FROM ticket_history WHERE ticket_id = ?',
                Bind => [ \$TicketID ],
            );

            while ( my @DataFetch = $DBObject->FetchrowArray() ) {
                push @{ $Self->{CreatedObjects}->{TicketHistory}->{ID} }, $DataFetch[0];
            }
        }
    }
    if ( $Index eq 'DynamicField' ) {

        my %IterationData = (
            Article => {
                Count => 3,
            },
            Ticket => {
                Count => 3,
            },
            CustomerUser => {
                Count => 4,
            },
        );

        for my $ObjectType ( sort keys %IterationData ) {
            my $Data = $IterationData{$ObjectType};
            for my $Counter ( 1 .. $Data->{Count} ) {
                my $ID = $DynamicFieldObject->DynamicFieldAdd(
                    InternalField => 0,
                    Name          => 'DF' . $ObjectType . $Counter,
                    Label         => 'a description',
                    FieldOrder    => $Counter,
                    FieldType     => 'Text',
                    ObjectType    => $ObjectType,
                    Config        => {},
                    ValidID       => 1,
                    UserID        => 1,
                );

                push @{ $Self->{CreatedObjects}->{DynamicField}->{ID} }, $ID;
            }
        }
    }
    if ( $Index eq 'CustomerUser' ) {

        # emitate problem with search engine to not search customer user with it
        $SearchObject->{Fallback} = 1;
        for ( 1 .. 10 ) {
            my $TestCustomerUserLogin = $HelperObject->TestCustomerUserCreate(
                Language  => 'en',    # optional, defaults to 'en' if not set
                KeepValid => 1,       # optional, defaults to 0
            );
            push @{ $Self->{CreatedObjects}->{CustomerUser}->{UserLogin} }, $TestCustomerUserLogin;
        }

        # revert search engine state
        $SearchObject->{Fallback} = 0;
    }
}

for my $Index ( sort keys %IndexesToTest ) {

    my $SQLTable = $IndexesToTest{$Index};

    # count previously added object data for each index
    $DBObject->Prepare(
        SQL => "SELECT COUNT(*) FROM $SQLTable",
    );

    my $DataCount;
    while ( my @DataFetch = $DBObject->FetchrowArray() ) {
        $DataCount = $DataFetch[0];
    }

    $Self->True(
        $ExpectedSQLDataCount{$Index} == $DataCount,
        "Created SQL data objects count check for table: $Index" .
            " - expected $ExpectedSQLDataCount{$Index}, is $DataCount"
    );

    my @Params = (
        '--index', $Index,
        '--limit', 60,
    );

    # 0 is exit code that identify success of reindexation
    my $ExitCode = $ReindexationObject->StartReindexation(
        Params => \@Params,
    );

    $Self->False(
        $ExitCode,
        "Re-indeaxtion run check for index: $Index."
    );

    if ( !$ExitCode ) {

        # search all indexed data in custom engine
        my $Search = $SearchObject->Search(
            Objects       => [$Index],
            QueryParams   => {},
            NoPermissions => 1,
            ResultType    => 'COUNT',
            UseSQLSearch  => 0,
        );

        $Self->True(
            $ExpectedSQLDataCount{$Index} == $DataCount,
            "Re-indeaxtion: indexed data count in custom engine check for index: $Index" .
                " - expected $ExpectedSQLDataCount{$Index}, is $Search->{$Index}"
        );
    }
}

# synchronization section

# change some objects
my %ChangedObjects;

for my $Index ( sort keys %IndexesToTest ) {
    my $SearchIndexObject   = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Index");
    my $ChangeTimeColumn    = $SearchIndexObject->{Config}->{ChangeTimeColumnName};
    my $ChangeTimeColumnSQL = $SearchIndexObject->{Fields}->{$ChangeTimeColumn}->{ColumnName};
    my $Identifier          = $SearchIndexObject->{Config}->{Identifier};
    my $IdentifierSQL       = $SearchIndexObject->{Fields}->{$Identifier}->{ColumnName};

    for my $Counter ( 1 .. 4 ) {
        my $DateTimeObject = $Kernel::OM->Create(
            'Kernel::System::DateTime',
        );

        # substract any days just to see that change time is different
        my $Success = $DateTimeObject->Subtract(
            Days => $Counter,
        );

        my $Property    = $Index eq 'CustomerUser' ? 'UserLogin' : 'ID';
        my $PropertySQL = $Property eq 'UserLogin' ? 'login'     : $IdentifierSQL;

        my $PropertySQLValue = $Self->{CreatedObjects}->{$Index}->{$Property}->[ -$Counter ];

        my $DateTimeString = $DateTimeObject->ToString();
        $DBObject->Do(
            SQL  => "UPDATE $IndexesToTest{$Index} SET $ChangeTimeColumnSQL = ? WHERE $PropertySQL = ?",
            Bind => [ \$DateTimeString, \$PropertySQLValue ],
        );

        $ChangedObjects{$Index}->{$Property}->{$PropertySQLValue} = 1;
    }
}

# delete some objects

# delete tickets

my %DeletedObjects;
my @ExistingTickets = @{ $Self->{CreatedObjects}->{Ticket}->{ID} };

# ticket deletion will also delete its ticket history and articles
for my $Counter ( 0 .. 4 ) {
    my $TicketID = $ExistingTickets[$Counter];
    my @Articles = $ArticleObject->ArticleList(
        TicketID => $TicketID,
    );

    my $ArticleID = $Articles[0]->{ArticleID};

    $DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_history WHERE ticket_id = ?',
        Bind => [ \$TicketID ],
    );
    my @FetchedTicketHistoryIDs;
    while ( my @DataFetch = $DBObject->FetchrowArray() ) {
        $DeletedObjects{TicketHistory}->{ID}->{ $DataFetch[0] } = 1;
        push @FetchedTicketHistoryIDs, $DataFetch[0];
    }

    my $Success = $TicketObject->TicketDelete(
        TicketID => $ExistingTickets[$Counter],
        UserID   => 1,
    );

    if ($Success) {
        $DeletedObjects{Ticket}->{ID}->{$TicketID}   = 1;
        $DeletedObjects{Article}->{ID}->{$ArticleID} = 1;
    }
    else {
        for my $ID (@FetchedTicketHistoryIDs) {
            delete $DeletedObjects{TicketHistory}->{ID}->{$ID};
        }
    }
}

# delete customer users
my @ExistingCustomerUsers = @{ $Self->{CreatedObjects}->{CustomerUser}->{UserLogin} };
for my $Counter ( 0 .. 4 ) {
    $DBObject->Do(
        SQL  => "DELETE FROM customer_user WHERE login = ?",
        Bind => [ \$ExistingCustomerUsers[$Counter] ],
    );

    $DeletedObjects{CustomerUser}->{ID}->{ $ExistingCustomerUsers[$Counter] } = 1;
}

# delete dynamic fields
my @ExistingDynamicFields = @{ $Self->{CreatedObjects}->{DynamicField}->{ID} };
for my $Counter ( 0 .. 4 ) {
    my $Success = $DynamicFieldObject->DynamicFieldDelete(
        ID      => $ExistingDynamicFields[$Counter],
        UserID  => 1,
        Reorder => 1,
    );

    $DeletedObjects{DynamicField}->{ID}->{ $ExistingDynamicFields[$Counter] } = 1;
}

# emitate problem with search engine to not search customer user with it
# and to prevent live-indexing of any customer user data
$SearchObject->{Fallback} = 1;

my %AddedObjects;

# create some new objects
for my $Counter ( 41 .. 60 ) {
    my $TicketID  = $HelperObject->TicketCreate();
    my $ArticleID = $HelperObject->ArticleCreate(
        TicketID => $TicketID,
    );
    $AddedObjects{Ticket}->{ID}->{$TicketID}   = 1;
    $AddedObjects{Article}->{ID}->{$ArticleID} = 1;

    $DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_history WHERE ticket_id = ?',
        Bind => [ \$TicketID ],
    );

    while ( my @DataFetch = $DBObject->FetchrowArray() ) {
        $AddedObjects{TicketHistory}->{ID}->{ $DataFetch[0] } = 1;
    }

    my $ID = $DynamicFieldObject->DynamicFieldAdd(
        InternalField => 0,
        Name          => 'DFTicket' . $Counter,
        Label         => 'a description',
        FieldOrder    => $Counter,
        FieldType     => 'Text',
        ObjectType    => 'Ticket',
        Config        => {},
        ValidID       => 1,
        UserID        => 1,
    );

    $AddedObjects{DynamicField}->{ID}->{$ID} = 1;

    my $TestCustomerUserLogin = $HelperObject->TestCustomerUserCreate(
        Language  => 'en',
        KeepValid => 1,
    );
    $AddedObjects{CustomerUser}->{UserLogin}->{$TestCustomerUserLogin} = 1;
}

# revert search engine state
$SearchObject->{Fallback} = 0;

# run synchronization
my %SynchronizationExpectedDataCount;

for my $Index ( sort keys %IndexesToTest ) {

    my $SQLTable = $IndexesToTest{$Index};

    $DBObject->Prepare(
        SQL => "SELECT COUNT(*) FROM $SQLTable",
    );

    my $DataCount;
    while ( my @DataFetch = $DBObject->FetchrowArray() ) {
        $DataCount = $DataFetch[0];
    }

    $SynchronizationExpectedDataCount{$Index} = $DataCount;

    my @Params = (
        '--index', $Index,
        '--sync'
    );

    # 0 is exit code that identify success of synchronization
    my $ExitCode = $ReindexationObject->StartReindexation(
        Params => \@Params,
    );

    $Self->False(
        $ExitCode,
        "Index synchronization test for index: $Index."
    );

    if ( !$ExitCode ) {
        my $Success = $SearchObject->IndexRefresh(
            Index => $Index,
        );

        $Self->True(
            $Success,
            "Refresh data action for index: $Index."
        );

        # search all indexed data in custom engine
        my $Search = $SearchObject->Search(
            Objects       => [$Index],
            QueryParams   => {},
            NoPermissions => 1,
            ResultType    => 'COUNT',
            UseSQLSearch  => 0,
        );

        $Self->True(
            $SynchronizationExpectedDataCount{$Index} == $Search->{$Index},
            "(Synchronization) Indexed data count in custom engine check for index: $Index" .
                " - expected $SynchronizationExpectedDataCount{$Index}, is $Search->{$Index}"
        );
    }
}

# check if data was updated in custom search engine
for my $Index ( sort keys %ChangedObjects ) {
    my $Property       = $Index eq 'CustomerUser' ? 'UserLogin' : 'ID';
    my $ContainChanges = IsHashRefWithData( $ChangedObjects{$Index}->{$Property} );

    $Self->True(
        $ContainChanges,
        "(Synchronization) Updated data entries detected for index: $Index."
    );

    if ($ContainChanges) {
        my $SearchIndexObject   = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Index");
        my $ChangeTimeColumn    = $SearchIndexObject->{Config}->{ChangeTimeColumnName};
        my $ChangeTimeColumnSQL = $SearchIndexObject->{Fields}->{$ChangeTimeColumn}->{ColumnName};
        my $Identifier          = $SearchIndexObject->{Config}->{Identifier};
        my $IdentifierSQL       = $SearchIndexObject->{Fields}->{$Identifier}->{ColumnName};
        my $DBTable             = $SearchIndexObject->{Config}->{IndexRealName};

        my $PropertySearchSQL = $Property eq 'UserLogin'
            ?
            $SearchIndexObject->{Fields}->{$Property}->{ColumnName}
            : $IdentifierSQL;

        for my $Value ( sort keys %{ $ChangedObjects{$Index}->{$Property} } ) {

            $DBObject->Prepare(
                SQL  => "SELECT $IdentifierSQL, $ChangeTimeColumnSQL FROM $DBTable WHERE $PropertySearchSQL = ?",
                Bind => [ \$Value ],
            );

            my %Data = (
                SQL          => {},
                CustomEngine => {},
            );
            while ( my @DataFetch = $DBObject->FetchrowArray() ) {
                $Data{SQL}->{ID}         = $DataFetch[0];
                $Data{SQL}->{ChangeTime} = $DataFetch[1];
            }

            # search in custom engine
            my $Search = $SearchObject->Search(
                Objects     => [$Index],
                QueryParams => {
                    $Identifier => $Data{SQL}->{ID},
                },
                Fields        => [ [ "${Index}_" . $Identifier, "${Index}_" . $ChangeTimeColumn ] ],
                NoPermissions => 1,
            );

            my $CustomEngineValidResponse =
                IsArrayRefWithData( $Search->{$Index} ) &&
                $Search->{$Index}->[0] &&
                $Search->{$Index}->[0]->{$ChangeTimeColumn};

            $Self->True(
                $CustomEngineValidResponse,
                "(Synchronization) Custom engine check for updated data valid response from index: $Index."
            );

            if ($CustomEngineValidResponse) {
                $Data{CustomEngine}->{ChangeTime} = $Search->{$Index}->[0]->{$ChangeTimeColumn};

                $Self->True(
                    $Data{CustomEngine}->{ChangeTime} &&
                        $Data{SQL}->{ChangeTime}      &&
                        $Data{CustomEngine}->{ChangeTime} eq $Data{SQL}->{ChangeTime},
                    "(Synchronization) Custom engine check for updated data during synchronization for index: $Index (for ID: $Data{SQL}->{ID})"
                );
            }
        }
    }
}

1;

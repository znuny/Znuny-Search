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

my $TicketObject          = $Kernel::OM->Get('Kernel::System::Ticket');
my $StateObject           = $Kernel::OM->Get('Kernel::System::State');
my $PriorityObject        = $Kernel::OM->Get('Kernel::System::Priority');
my $HelperObject          = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $SearchObject          = $Kernel::OM->Get('Kernel::System::Search');
my $SearchChildObject     = $Kernel::OM->Get('Kernel::System::Search::Object');
my $ZnunyHelperObject     = $Kernel::OM->Get('Kernel::System::ZnunyHelper');
my $ConfigObject          = $Kernel::OM->Get('Kernel::Config');
my $UserObject            = $Kernel::OM->Get('Kernel::System::User');
my $CustomerUserObject    = $Kernel::OM->Get('Kernel::System::CustomerUser');
my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
my $ServiceObject         = $Kernel::OM->Get('Kernel::System::Service');
my $TypeObject            = $Kernel::OM->Get('Kernel::System::Type');
my $QueueObject           = $Kernel::OM->Get('Kernel::System::Queue');
my $SLAObject             = $Kernel::OM->Get('Kernel::System::SLA');
my $CacheObject           = $Kernel::OM->Get('Kernel::System::Cache');

# just for gitlab pipeline to pass this test
if ( !$SearchObject->{ConnectObject} ) {
    return 1;
}

my $ActiveEngine = $SearchObject->{Config}->{ActiveEngine};

$Self->True(
    $ActiveEngine,
    "Active engine ($SearchObject->{Config}->{ActiveEngine}) exists, search engine.",
);

return if !$ActiveEngine;

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

# enable service/sla/responsible
$ConfigObject->Set(
    Key   => 'Ticket::Service',
    Value => 1,
);

$ConfigObject->Set(
    Key   => 'Ticket::Type',
    Value => 1,
);

$ConfigObject->Set(
    Key   => 'Ticket::Responsible',
    Value => 1,
);

my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
my $ArticleIdentifier   = $SearchArticleObject->{Config}->{Identifier};

my $ReindexationStep = 4;

$ConfigObject->Set(
    Key   => 'SearchEngine::Reindexation###Settings',
    Value => {
        ReindexationStep => $ReindexationStep,
    },
);

my %QueryParams;
my %LookupQueryParams;

my $Object = {
    Basic => {
        User => {
            ID => 1,
        },
        Queue => {
            Name    => 'some-queue',
            GroupID => 1,
        },
        SLA => {
            Name => 'some-sla',
        },
        Lock => {
            Name => 'unlock',
        },
        Type => {
            Name => 'some-type',
        },
        Service => {
            Name => 'some-service'
        },
        Owner => {
            Login => 'some-owner'
        },
        Responsible => {
            Login => 'mhuber'
        },
        Priority => {
            Name => 'some-priority'
        },
        State => {
            Name => 'some-state'
        },
        Customer => {
            Name => 'some-customer-company-name',
            ID   => 'some-customer-company-id'
        },
        CustomerUser => {
            ID => 'some-customer-id'
        },
    }
};

my $AdminUserLogin = $UserObject->UserLookup(
    UserID => $Object->{Basic}->{User}->{ID},
    Silent => 1,
);

# apply create by, change by properties
for my $Property (qw(CreateByLogin ChangeByLogin)) {
    $Object->{Basic}->{$Property}->{Name} = $AdminUserLogin;
    $LookupQueryParams{$Property} = $AdminUserLogin;

    my $PropertyWithoutLogin = substr $Property, 0, -5;
    $QueryParams{$PropertyWithoutLogin} = $Object->{Basic}->{User}->{ID};
}

my $QueueID = $QueueObject->QueueAdd(
    Name            => $Object->{Basic}->{Queue}->{Name},
    ValidID         => 1,
    GroupID         => $Object->{Basic}->{Queue}->{GroupID},
    SystemAddressID => 1,
    SalutationID    => 1,
    SignatureID     => 1,
    Comment         => 'Some comment',
    UserID          => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{Queue}       = $Object->{Basic}->{Queue}->{Name};
$Object->{Basic}->{Queue}->{ID} = $QueueID;
$QueryParams{QueueID}           = $QueueID;

$Self->True(
    $QueueID,
    "Basic Queue (id: $QueueID) created/exists, sql.",
);

my $SLAID = $SLAObject->SLAAdd(
    Name    => $Object->{Basic}->{SLA}->{Name},
    ValidID => 1,
    UserID  => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{SLA} = $Object->{Basic}->{SLA}->{Name};
$QueryParams{SLAID}     = $SLAID;

$Self->True(
    $SLAID,
    "Basic SLA (id: $SLAID) created/exists, sql.",
);

my $LockObject = $Kernel::OM->Get('Kernel::System::Lock');
my $LockID     = $LockObject->LockLookup( Lock => 'unlock' );
$LookupQueryParams{Lock} = $Object->{Basic}->{Lock}->{Name};
$QueryParams{LockID}     = $LockID;

$Self->True(
    $LockID,
    "Basic Lock (id: $LockID) created/exists, sql.",
);

my $TypeID = $TypeObject->TypeAdd(
    Name    => $Object->{Basic}->{Type}->{Name},
    ValidID => 1,
    UserID  => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{Type} = $Object->{Basic}->{Type}->{Name};
$QueryParams{TypeID}     = $TypeID;

$Self->True(
    $TypeID,
    "Basic Type (id: $TypeID) created/exists, sql.",
);

my $ServiceID = $ServiceObject->ServiceAdd(
    Name    => $Object->{Basic}->{Service}->{Name},
    ValidID => 1,
    UserID  => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{Service} = $Object->{Basic}->{Service}->{Name};
$QueryParams{ServiceID}     = $ServiceID;

$Self->True(
    $ServiceID,
    "Basic Service (id: $ServiceID) created/exists, sql.",
);

# add example user
my $UserResponsibleID = $UserObject->UserAdd(
    UserFirstname => 'Huber',
    UserLastname  => 'Manfred',
    UserLogin     => $Object->{Basic}->{Responsible}->{Login},
    UserEmail     => 'email2@mail.com',
    ValidID       => 1,
    ChangeUserID  => 1,
);
$LookupQueryParams{Responsible} = $Object->{Basic}->{Responsible}->{Login};
$QueryParams{ResponsibleID}     = $UserResponsibleID;

$Self->True(
    $UserResponsibleID,
    "Basic Responsible (id: $UserResponsibleID) created/exists, sql.",
);

# add example user
my $UserOwnerID = $UserObject->UserAdd(
    UserFirstname => 'Huber',
    UserLastname  => 'Manfred',
    UserLogin     => $Object->{Basic}->{Owner}->{Login},
    UserEmail     => 'email@mail.com',
    ValidID       => 1,
    ChangeUserID  => 1,
);
$LookupQueryParams{Owner} = $Object->{Basic}->{Owner}->{Login};
$QueryParams{OwnerID}     = $UserOwnerID;

$Self->True(
    $UserOwnerID,
    "Basic Owner (id: $UserOwnerID) created/exists, sql.",
);

my $PrioID = $PriorityObject->PriorityAdd(
    Name    => $Object->{Basic}->{Priority}->{Name},
    ValidID => 1,
    UserID  => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{Priority} = $Object->{Basic}->{Priority}->{Name};
$QueryParams{PriorityID}     = $PrioID;

$Self->True(
    $PrioID,
    "Basic Priority (id: $PrioID) created/exists, sql.",
);

my $StateID = $StateObject->StateAdd(
    Name    => $Object->{Basic}->{State}->{Name},
    Comment => 'some comment',
    ValidID => 1,
    TypeID  => 1,
    UserID  => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{State} = $Object->{Basic}->{State}->{Name};
$QueryParams{StateID}     = $StateID;

$Self->True(
    $StateID,
    "Basic State (id: $StateID) created/exists, sql.",
);

my $CustomerCompanyID = $CustomerCompanyObject->CustomerCompanyAdd(
    CustomerID             => $Object->{Basic}->{Customer}->{ID},
    CustomerCompanyName    => $Object->{Basic}->{Customer}->{Name},
    CustomerCompanyStreet  => '5201 Blue Lagoon Drive',
    CustomerCompanyZIP     => '33126',
    CustomerCompanyCity    => 'Miami',
    CustomerCompanyCountry => 'USA',
    CustomerCompanyURL     => 'http://www.example.org',
    CustomerCompanyComment => 'some comment',
    ValidID                => 1,
    UserID                 => $Object->{Basic}->{User}->{ID},
);
$LookupQueryParams{Customer} = $Object->{Basic}->{Customer}->{Name};
$QueryParams{CustomerID}     = $CustomerCompanyID;

$Self->True(
    $CustomerCompanyID,
    "Basic CustomerCompany (id: $CustomerCompanyID) created/exists, sql.",
);

my $UserLogin = $CustomerUserObject->CustomerUserAdd(
    Source         => 'CustomerUser',                           # CustomerUser source config
    UserFirstname  => 'Huber',
    UserLastname   => 'Manfred',
    UserCustomerID => $Object->{Basic}->{CustomerUser}->{ID},
    UserLogin      => 'some-customeruser',
    UserPassword   => 'some-pass',                              # not required
    UserEmail      => 'email3@mail.com',
    ValidID        => 1,
    UserID         => $Object->{Basic}->{User}->{ID},
);

# Customer equals but is stil lookuped for TicketCreate function to match
$LookupQueryParams{CustomerUser} = $Object->{Basic}->{CustomerUser}->{ID};
$QueryParams{CustomerUserID}     = $Object->{Basic}->{CustomerUser}->{ID};

$Self->True(
    $UserLogin,
    "Basic CustomerUser (id: $Object->{Basic}->{CustomerUser}->{ID}) created/exists, sql.",
);

# create basic ticket
my $QueryParams = {
    BasicTicket => {
        %QueryParams,
        Title => 'some-ticket-title',
    }
};

my @TicketsData;

# create basic tickets
for ( 1 .. 2 ) {
    my $TicketNumber = $TicketObject->TicketCreateNumber();

    # create basic ticket
    my $TicketID = $TicketObject->TicketCreate(
        %{ $QueryParams->{BasicTicket} },
        TN           => $TicketNumber,
        UserID       => $Object->{Basic}->{User}->{ID},
        CustomerUser => $QueryParams->{BasicTicket}->{CustomerUserID}
    );

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        UserID        => $Object->{Basic}->{User}->{ID},
    );

    $Self->True(
        $TicketID,
        "Basic ticket (id: $TicketID) created, sql.",
    );

    my @ArticlesIDs;

    # create basic articles
    for ( 1 .. 3 ) {
        my $ArticleID = $HelperObject->ArticleCreate(
            TicketID             => $TicketID,
            SenderType           => 'agent',
            IsVisibleForCustomer => 0,
        );

        push @ArticlesIDs, $ArticleID;
    }

    push @TicketsData, {
        TicketID  => $TicketID,
        ArticleID => \@ArticlesIDs,
    };
}

$StartQueuedIndexation->();

my @ArticlesSearch = ( @{ $TicketsData[0]->{ArticleID} }, @{ $TicketsData[1]->{ArticleID} } );

# search for basic articles in elasticsearch
my $Search = $SearchObject->Search(
    Objects     => ["Article"],
    QueryParams => {
        $ArticleIdentifier => \@ArticlesSearch,
        UserID             => $Object->{Basic}->{User}->{ID},
    },
    Limit        => 10,
    UseSQLSearch => 0,
);

$Self->True(
    IsHashRefWithData($Search) && IsArrayRefWithData( $Search->{Article} ) && scalar @{ $Search->{Article} } == 6,
    "Live indexing check: basic articles (ids: @ArticlesSearch) created on event ArticleCreate, elasticsearch.",
);

$Search = $SearchObject->Search(
    Objects     => ["Article"],
    QueryParams => {
        $ArticleIdentifier => \@ArticlesSearch,
        GroupID            => [2],
    },
    Limit        => 10,
    UseSQLSearch => 0,
);

$Self->False(
    IsArrayRefWithData( $Search->{Article} ) ? 1 : 0,
    "Permission check (permissions rejected, articles id: @ArticlesSearch) created on event ArticleCreate, elasticsearch.",
);

$CacheObject->CleanUp(
    Type => 'Queue',
);

# queue update event check
my $Success = $QueueObject->QueueUpdate(
    QueueID         => $Object->{Basic}->{Queue}->{ID},
    Name            => $Object->{Basic}->{Queue}->{Name},
    ValidID         => 1,
    GroupID         => 2,
    SystemAddressID => 1,
    SalutationID    => 1,
    SignatureID     => 1,
    UserID          => 1,
    FollowUpID      => 1,
    Comment         => 'some-comment',
);

$Self->True(
    $Success,
    "Queue group id update check, sql.",
);

$StartQueuedIndexation->();

$Search = $SearchObject->Search(
    Objects     => ["Article"],
    QueryParams => {
        $ArticleIdentifier => \@ArticlesSearch,
        GroupID            => [2],
    },
    Limit        => 10,
    UseSQLSearch => 0,
);

$SearchObject->IndexRefresh(
    Index => 'Article',
);

$Self->True(
    IsHashRefWithData($Search) && IsArrayRefWithData( $Search->{Article} ) && scalar @{ $Search->{Article} } == 6,
    "Permission check (after re-assigned correct permissions, articles id: @ArticlesSearch), elasticsearch.",
);

# create second queue
my $SecondQueueID = $QueueObject->QueueAdd(
    Name            => $Object->{Basic}->{Queue}->{Name} . '2',
    ValidID         => 1,
    GroupID         => 3,
    SystemAddressID => 1,
    SalutationID    => 1,
    SignatureID     => 1,
    Comment         => 'Some comment',
    UserID          => $Object->{Basic}->{User}->{ID},
);

$Self->True(
    $SecondQueueID,
    "Second queue (id: $SecondQueueID) created, sql.",
);

my $FirstTicketID = $TicketsData[0]->{TicketID};

$Success = $TicketObject->TicketQueueSet(
    QueueID  => $SecondQueueID,
    TicketID => $FirstTicketID,
    UserID   => 1,
);

$Self->True(
    $SecondQueueID,
    "Second queue set to first created ticket (queue id: $SecondQueueID, ticket id: $FirstTicketID), sql.",
);

# queue change means ticket and it's articles have now group id 3
# run indexation queue and check this case
$StartQueuedIndexation->();

# 3 out of 6 articles permissions were changed, so 3 articles should be found with correct permission
$Search = $SearchObject->Search(
    Objects     => ["Article"],
    QueryParams => {
        $ArticleIdentifier => \@ArticlesSearch,
        GroupID            => [3],
    },
    Limit        => 10,
    OrderBy      => ['Up'],
    SortBy       => ['ArticleID'],
    UseSQLSearch => 0,
    Fields       => [ ['Article_ArticleID'] ]
);

$Self->IsDeeply(
    $Search,
    {
        Article => [
            { ArticleID => $TicketsData[0]->{ArticleID}->[0] },
            { ArticleID => $TicketsData[0]->{ArticleID}->[1] },
            { ArticleID => $TicketsData[0]->{ArticleID}->[2] },
        ]
    },
    "Permission check (after changed queue of first ticket to another queue, articles id: @ArticlesSearch), elasticsearch.",
);

my $SecondTicketID = $TicketsData[1]->{TicketID};

$Success = $TicketObject->TicketMerge(
    MainTicketID  => $FirstTicketID,
    MergeTicketID => $SecondTicketID,
    UserID        => $Self->{UserID},
);

$Self->True(
    $Success,
    "Second ticket merge into first ticket (first ticket id: $FirstTicketID, second ticket id: $SecondTicketID), sql.",
);

my %Ticket = $TicketObject->TicketGet(
    TicketID => $FirstTicketID,
    UserID   => 1,
);

my %Ticket2 = $TicketObject->TicketGet(
    TicketID => $SecondTicketID,
    UserID   => 1,
);

1;

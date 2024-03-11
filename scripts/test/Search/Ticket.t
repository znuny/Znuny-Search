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
my $DBObject              = $Kernel::OM->Get('Kernel::System::DB');
my $UserObject            = $Kernel::OM->Get('Kernel::System::User');
my $CustomerUserObject    = $Kernel::OM->Get('Kernel::System::CustomerUser');
my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
my $ServiceObject         = $Kernel::OM->Get('Kernel::System::Service');
my $TypeObject            = $Kernel::OM->Get('Kernel::System::Type');
my $QueueObject           = $Kernel::OM->Get('Kernel::System::Queue');
my $SLAObject             = $Kernel::OM->Get('Kernel::System::SLA');
my $JSONObject            = $Kernel::OM->Get('Kernel::System::JSON');
my $ArticleObject         = $Kernel::OM->Get('Kernel::System::Ticket::Article');

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

# enable attachment indexation if for some reason it was disabled
$ConfigObject->Set(
    Key   => "SearchEngine::Settings::Index::${ActiveEngine}::Ticket",
    Value => {
        '000-Framework' => {
            IndexAttachments => 1,
        }
    },
);

my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
my $TicketQueryObject  = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

my $ReindexationStep = 4;

$ConfigObject->Set(
    Key   => 'SearchEngine::Reindexation###Settings',
    Value => {
        ReindexationStep => $ReindexationStep,
    },
);

my $TicketNumber = $TicketObject->TicketCreateNumber();
my %QueryParams;
my %LookupQueryParams;

my $Object = {
    Basic => {
        User => {
            ID => 1,
        },
        Queue => {
            Name      => 'some-queue',
            GroupID   => 1,
            LookupKey => 'QueueID',
            Update    => [
                {
                    Name    => 'some-queue2',
                    GroupID => 2,
                }
            ],
            Remove => 1,
        },
        SLA => {
            Name      => 'some-sla',
            LookupKey => 'SLAID',
        },
        Lock => {
            Name      => 'unlock',
            LookupKey => 'LockID',
        },
        Type => {
            Name      => 'some-type',
            LookupKey => 'TypeID',
        },
        Service => {
            Name      => 'some-service',
            LookupKey => 'ServiceID',
        },
        Owner => {
            Login     => 'some-owner',
            LookupKey => 'OwnerID',
        },
        Responsible => {
            Login     => 'mhuber',
            LookupKey => 'ResponsibleID',
        },
        Priority => {
            Name      => 'some-priority',
            LookupKey => 'PriorityID',
        },
        State => {
            Name      => 'some-state',
            LookupKey => 'StateID',
        },
        Customer => {
            Name      => 'some-customer-company-name',
            ID        => 'some-customer-company-id',
            LookupKey => 'CustomerID',
        },
        CustomerUser => {
            ID        => 'some-customer-id',
            LookupKey => 'CustomerUserID',
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
$LookupQueryParams{Queue} = $Object->{Basic}->{Queue}->{Name};
$QueryParams{QueueID}     = $QueueID;

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

my %LookupQueryParamsSave = %LookupQueryParams;

# lookup mechanism deletes param "QueryParams" for each lookup
# finally there will be empty QueryParams if all fields
# will be converted
my $LookupTicketParams = $TicketQueryObject->LookupTicketFields(
    QueryParams => \%LookupQueryParams,
);

# re-assign lookup query params
%LookupQueryParams = %LookupQueryParamsSave;

# until now %QueryParams contains all query param id values
# check if lookup mechanism assigned corrects ids until now
for my $Param ( sort keys %QueryParams ) {
    my $LookuppedParam = delete $LookupTicketParams->{$Param};
    my $IsOk;
    my $LookuppedValue = '';
    if (
        $LookuppedParam
        && $LookuppedParam->{Value}
        &&
        $LookuppedParam->{Value}->[0] && $QueryParams{$Param} eq $LookuppedParam->{Value}->[0]
        )
    {
        $IsOk           = 1;
        $LookuppedValue = $LookuppedParam->{Value}->[0];
    }
    $Self->True(
        $IsOk,
        "Lookup mechanism correct id set check for $Param: $QueryParams{$Param} <=> $LookuppedValue.",
    );
}

# check if lookup mechanism returned any data that was not expected
my $AdditionalDataStrg     = '';
my $ContainsAdditionalData = IsHashRefWithData($LookupTicketParams)
    || IsArrayRefWithData($LookupTicketParams)
    || IsStringWithData($LookupTicketParams);

if ($ContainsAdditionalData) {
    my $JSON = $JSONObject->Encode(
        Data => $LookupTicketParams,
    );

    if ($JSON) {
        $AdditionalDataStrg = " This data is not expected: $JSON.";
    }
}

$Self->False(
    $ContainsAdditionalData,
    "Check for returning more data from lookup mechanism than it should.$AdditionalDataStrg",
);

# create basic ticket
my $QueryParams = {
    BasicTicket => {
        %QueryParams,
        Title => 'some-ticket-title',
        TN    => $TicketNumber,
    },
    BasicTicketLookup => {
        %LookupQueryParams,
        Title => 'some-ticket-title',
        TN    => $TicketNumber,
    }
};

# create basic ticket
my $TicketID = $TicketObject->TicketCreate(
    %{ $QueryParams->{BasicTicket} },
    UserID => $Object->{Basic}->{User}->{ID},

    # api of TicketCreate uses CustomerUser instead of CustomerUserID
    # but esentially those are the same with api of Elasticsearch
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

$StartQueuedIndexation->();

# refresh Ticket index
$SearchObject->IndexRefresh(
    Index => 'Ticket',
);

my %ESCompatibleQueryParams = %{ $QueryParams->{BasicTicket} };
$ESCompatibleQueryParams{TicketNumber} = delete $ESCompatibleQueryParams{TN};

# search for basic ticket in elasticsearch
my $Search = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        %ESCompatibleQueryParams,
        UserID => $Object->{Basic}->{User}->{ID},
    },
    Limit        => 1,
    UseSQLSearch => 0,
);

# search for basic ticket in elasticsearch
# use lookup query params to check if response will be the
# same as call that uses ids
my $SearchLookup = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        %ESCompatibleQueryParams,
        UserID => $Object->{Basic}->{User}->{ID},
    },
    Limit        => 1,
    UseSQLSearch => 0,
);

# compare response of lookup query params and query params that contains ids
$Self->IsDeeply(
    $Search,
    $SearchLookup,
    "(Engine => Engine lookup mechanism) Response check for same query params.",
);

# check if correct response was found
my %BasicTicketSearch = IsArrayRefWithData( $Search->{Ticket} ) &&
    IsHashRefWithData( $Search->{Ticket}->[0] )
    ? %{ $Search->{Ticket}->[0] } : ();

my $TicketFound = keys %BasicTicketSearch;

$Self->True(
    $TicketFound,
    "Live indexing check: basic ticket (id: $TicketID) created on event TicketCreate, elasticsearch.",
);

# get all internal and external fields for index
my $AllFields = {
    Ticket => {
        Fields         => $SearchTicketObject->{Fields},
        ExternalFields => $SearchTicketObject->{ExternalFields},
    }
};

my %TicketFieldsToCheck         = %{ $AllFields->{Ticket}->{Fields} };
my %TicketExternalFieldsToCheck = %{ $AllFields->{Ticket}->{ExternalFields} };

# check if field and external field name is the same
for my $ExternalField ( sort keys %TicketExternalFieldsToCheck ) {
    $Self->False(
        $TicketFieldsToCheck{$ExternalField},
        "Fields config check: identify if any internal and external field have the same name (check for:
         $ExternalField",
    );
}

my $SearchResultIncludesPossibleFields;
my %Matched;

# identify if response contains fields from definition
# that is: Kernel/System/Search/Object/Default/Ticket.pm
for my $Property ( sort keys %BasicTicketSearch ) {
    if ( $TicketFieldsToCheck{$Property} ) {
        $Matched{Fields}->{$Property} = 1;
    }
    elsif ( $TicketExternalFieldsToCheck{$Property} ) {
        $Matched{ExternalFields}->{$Property} = 1;
    }
    else {
        $Matched{FieldNotFromConfig}->{$Property} = 1;
    }
}

# iterate for fields from definition and check if all was matched
for my $Field ( sort keys %TicketFieldsToCheck ) {
    my $MatchedField = $Matched{Fields}->{$Field};

    $Self->True(
        $MatchedField,
        'Live indexing check: identify if field was returned in the response (check for: '
            . $Field,
    );

    if ($MatchedField) {
        delete $TicketFieldsToCheck{$Field};
    }
}

# iterate for external fields from definition and check if all was matched
for my $Field ( sort keys %TicketExternalFieldsToCheck ) {
    my $MatchedField = $Matched{ExternalFields}->{$Field};

    $Self->True(
        $MatchedField,
        'Live indexing check: identify if external field was returned in the response (check for: '
            . $Field,
    );

    if ($MatchedField) {
        delete $TicketExternalFieldsToCheck{$Field};
    }
}

my $NotExpectedData = IsHashRefWithData( $Matched{FieldNotFromConfig} );

# check if lookup mechanism returned any data that was not expected
$AdditionalDataStrg = '';

if ($NotExpectedData) {
    my $JSON = $JSONObject->Encode(
        Data => $NotExpectedData,
    );

    if ($JSON) {
        $AdditionalDataStrg = " This data is not expected: $JSON.";
    }
}

$Self->False(
    $NotExpectedData,
    "Live indexing check: returning more data from Ticket search than it should be.$AdditionalDataStrg",
);

# search for basic ticket in elasticsearch with no permissions
# response should be empty
my $SearchNoPermissions = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        %ESCompatibleQueryParams,
    },
    Limit        => 1,
    UseSQLSearch => 0,
);

# check if correct response was found
my $NoPermissionTicketFound =
    IsArrayRefWithData( $SearchNoPermissions->{Ticket} ) &&
    IsHashRefWithData( $SearchNoPermissions->{Ticket}->[0] )
    ? 1 : 0;

$Self->False(
    $NoPermissionTicketFound,
    "Basic ticket (id: $TicketID) search with no permissions specified, elasticsearch.",
);

# search for basic ticket in elasticsearch with group id specified
# as permission
# response should be found
my $SearchPermissionsGroup = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        %ESCompatibleQueryParams,
        GroupID => [ $Object->{Basic}->{Queue}->{GroupID} ],
    },
    Limit        => 1,
    UseSQLSearch => 0,
);

# check if correct response was found
my $GroupPermissionTicketFound =
    IsArrayRefWithData( $SearchPermissionsGroup->{Ticket} ) &&
    IsHashRefWithData( $SearchPermissionsGroup->{Ticket}->[0] )
    ? 1 : 0;

$Self->True(
    $SearchPermissionsGroup,
    "Basic ticket (id: $TicketID) search with group permission specified, elasticsearch.",
);

my $GroupIDToUpdateTo   = $Object->{Basic}->{Queue}->{Update}->[0]->{GroupID};
my $QueueNameToUpdateTo = $Object->{Basic}->{Queue}->{Update}->[0]->{Name};

# update ticket related entities
my $Success = $QueueObject->QueueUpdate(
    QueueID         => $QueueID,
    Name            => $Object->{Basic}->{Queue}->{Update}->[0]->{Name},
    ValidID         => 1,
    GroupID         => $GroupIDToUpdateTo,
    SystemAddressID => 1,
    SalutationID    => 1,
    SignatureID     => 1,
    UserID          => $Object->{Basic}->{User}->{ID},
    FollowUpID      => 1,
    Comment         => 'Some Comment2',
    DefaultSignKey  => '',
    UnlockTimeOut   => '',
    FollowUpLock    => 1,
    ParentQueueID   => '',
);

$StartQueuedIndexation->();

# refresh Ticket index as live-indexing is asynchronous
$SearchObject->IndexRefresh(
    Index => 'Ticket',
);

# after queue groupid was changed ticket should be reindexed
my $TicketAfterQueueUpdate = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        %ESCompatibleQueryParams,
        UserID => $Object->{Basic}->{User}->{ID},
    },
    Limit        => 1,
    UseSQLSearch => 0,
);

my $GroupIDFromResponse =
    $TicketAfterQueueUpdate->{Ticket} &&
    $TicketAfterQueueUpdate->{Ticket}->[0]
    ?
    $TicketAfterQueueUpdate->{Ticket}->[0]->{GroupID}
    : undef;

$Self->True(
    $GroupIDFromResponse && $GroupIDFromResponse eq $GroupIDToUpdateTo,
    "Live reindexing check: queue GroupID to " .
        "$TicketAfterQueueUpdate->{Ticket}->[0]->{GroupID} change reindexed for ticket: $TicketID.",
);

# search ticket for changed recently queue name
my $TicketChangedQueueNameSearch = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        TicketID => $TicketID,
        Queue    => $QueueNameToUpdateTo,
        UserID   => $Object->{Basic}->{User}->{ID},
    },
    Limit        => 1,
    UseSQLSearch => 0,
);

my $TicketIDWasFound =
    $TicketAfterQueueUpdate->{Ticket} &&
    $TicketAfterQueueUpdate->{Ticket}->[0]
    ?
    $TicketAfterQueueUpdate->{Ticket}->[0]->{TicketID}
    : undef;

$Self->True(
    $TicketIDWasFound && $TicketIDWasFound eq $TicketID,
    "Live reindexing check: search ticket by new Queue name ($QueueNameToUpdateTo) ",
);

# test queue operation mechanism
my @TicketIDsToTest;
my @Tests = (
    {
        Name      => 'Attachments exists - ticket queue operation',
        Operation => 'ObjectIndexSet',
        Data      => {
            Attachment => [
                {
                    Filename    => 'csvfile.csv',
                    Content     => '123',
                    ContentType => 'text/csv',
                },
                {
                    Filename    => 'pngfile.png',
                    Content     => 'empty',
                    ContentType => 'image/png; name=pngfile.png',
                },
            ]
        },
        ExpectedResult => {
            AfterAttachmentUpload => {
                Ticket => [
                    {
                        Articles => [
                            {
                                Attachments => [
                                    {
                                        ID                 => '1',
                                        AttachmentContent  => '123',
                                        Filename           => 'csvfile.csv',
                                        ContentType        => 'text/csv',
                                        ContentID          => '',
                                        ContentAlternative => '',
                                        Disposition        => 'attachment',
                                        Content            => 'MTIz'
                                    },
                                    {
                                        ID                 => '2',
                                        AttachmentContent  => 'empty',
                                        Filename           => 'pngfile.png',
                                        ContentType        => 'image/png; name=pngfile.png',
                                        ContentID          => '',
                                        ContentAlternative => '',
                                        Disposition        => 'attachment',
                                        Content            => 'ZW1wdHk='
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            DisabledAttachmentsQueryParam => {
                'Ticket' => [],
            },
            DisabledAttachmentsFields => {
                'Ticket' => [],
            },
        },

    }
);
for ( 1 .. 10 ) {
    my $TN = $TicketObject->TicketCreateNumber();

    # create basic ticket
    my $TicketID = $TicketObject->TicketCreate(
        %{ $QueryParams->{BasicTicket} },
        UserID => $Object->{Basic}->{User}->{ID},
        TN     => $TN,

        # api of TicketCreate uses CustomerUser instead of CustomerUserID
        # but esentially those are the same with api of Elasticsearch
        CustomerUser => $QueryParams->{BasicTicket}->{CustomerUserID}
    );
    my $ArticleID = $HelperObject->ArticleCreate(
        TicketID             => $TicketID,
        SenderType           => 'agent',
        IsVisibleForCustomer => 1,
    );
    push @TicketIDsToTest, $TicketID;
}

my @TicketIDsContainsAttachments;

# add attachments to 5 first tickets
for my $Index ( 0 .. 4 ) {
    my $TicketIDToTest = $TicketIDsToTest[$Index];
    my $Success;
    my $Counter  = 0;
    my @Articles = $ArticleObject->ArticleList(
        TicketID  => $TicketIDToTest,
        OnlyFirst => 1,
    );

    for my $AttachmentData ( @{ $Tests[0]->{Data}->{Attachment} } ) {
        if ( !( $Counter && !$Success ) ) {
            $Success = $ArticleObject->ArticleWriteAttachment(
                TicketID => $TicketIDToTest,
                %{$AttachmentData},
                Disposition => 'attachment',
                ArticleID   => $Articles[0]->{ArticleID},
                UserID      => 1,
            );

            $Tests[0]->{ExpectedResult}->{AfterAttachmentUpload}->{Ticket}->
                [0]->{Articles}->[0]->{Attachments}->[$Counter]->{ArticleID} = $Articles[0]->{ArticleID} if $Index == 0;
        }
        $Counter++;
    }
    push @TicketIDsContainsAttachments, $TicketIDToTest if $Success;
}

$Tests[0]->{ExpectedResult}->{DisabledAttachmentsFields}->{Ticket}->[0]->{TicketID} = $TicketIDsContainsAttachments[0];

$StartQueuedIndexation->();

# refresh Ticket index
$SearchObject->IndexRefresh(
    Index => 'Ticket',
);

my $TicketWithAttachmentsParams = {
    Objects     => ["Ticket"],
    QueryParams => {
        %ESCompatibleQueryParams,
        UserID              => $Object->{Basic}->{User}->{ID},
        Attachment_Filename => {
            Operator => '=',
            Value    => $Tests[0]->{Data}->{Attachment}->[0]->{Filename},
        },
        TicketID     => \@TicketIDsContainsAttachments,
        TicketNumber => undef,
    },
    SortBy       => ['TicketID'],
    OrderBy      => ['Up'],
    Fields       => [ ['Attachment_*'] ],
    Limit        => 1,
    UseSQLSearch => 0,
};

my $TicketWithAttachmentIndexed = $SearchObject->Search(
    %{$TicketWithAttachmentsParams},
);

$Self->IsDeeply(
    $TicketWithAttachmentIndexed,
    $Tests[0]->{ExpectedResult}->{AfterAttachmentUpload},
    "(Engine search) Response check, search by attachment filename after attachment upload.",
);

# disable attachment indexation
$ConfigObject->Set(
    Key   => "SearchEngine::Settings::Index::${ActiveEngine}::Ticket",
    Value => {
        '000-Framework' => {
            IndexAttachments => 0,
        }
    },
);

# recreate objects to initialize correct fields
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Kernel::System::Search::Object::Default::Ticket',
        'Kernel::System::Search::Object::Query::Ticket',
    ],
);

$SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
$TicketQueryObject  = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

# use the same search query as previous
my $TicketWithAttachmentIndexedDisabled = $SearchObject->Search(
    %{$TicketWithAttachmentsParams},
);

$Self->IsDeeply(
    $TicketWithAttachmentIndexedDisabled,
    $Tests[0]->{ExpectedResult}->{DisabledAttachmentsQueryParam},
    "(Engine search) Response check, search by attachment filename after attachment upload with disabled attachment indexation.",
);

# try to retrieve attachment data after attachments are disabled on ticket that contains attachment
# but does not use attachment properties inside QueryParams parameter
my $TicketRetrieveAttachmentDisabled = $SearchObject->Search(
    Objects     => ["Ticket"],
    QueryParams => {
        UserID   => $Object->{Basic}->{User}->{ID},
        TicketID => \@TicketIDsContainsAttachments,
    },
    SortBy       => ['TicketID'],
    OrderBy      => ['Up'],
    Fields       => [ [ 'Attachment_*', 'Ticket_TicketID' ] ],
    Limit        => 1,
    UseSQLSearch => 0,
);

$Self->IsDeeply(
    $TicketRetrieveAttachmentDisabled,
    $Tests[0]->{ExpectedResult}->{DisabledAttachmentsFields},
    "(Engine search) Response check, search by ticket id after attachment upload with disabled attachment indexation and try to retrieve attachment data.",
);

# add attachment to next ticket, notice that attachment indexation is disabled
my $Counter  = 0;
my @Articles = $ArticleObject->ArticleList(
    TicketID  => $TicketIDsToTest[6],
    OnlyFirst => 1,
);

undef $Success;

for my $AttachmentData ( @{ $Tests[0]->{Data}->{Attachment} } ) {
    $Success = $ArticleObject->ArticleWriteAttachment(
        TicketID => $TicketIDsToTest[6],
        %{$AttachmentData},
        Disposition => 'attachment',
        ArticleID   => $Articles[0]->{ArticleID},
        UserID      => 1,
    );

    $Self->True(
        $Success,
        "Writing attachment into article (TicketID: $TicketIDsToTest[6], ArticleID: $Articles[0]->{ArticleID}) created/exists, sql.",
    );
}

# get queued data for indexing
my $Queue = $SearchChildObject->IndexObjectQueueGet(
    Index => 'Ticket',
);

$Self->False(
    $Queue,
    "ArticleWriteAttachment event when attachment indexing is disabled check, queue not created/exists, sql.",
);

my $ArticleBackendObject = $ArticleObject->BackendForArticle(
    TicketID  => $TicketIDsToTest[6],
    ArticleID => $Articles[0]->{ArticleID},
);

# remove all attachments
$Success = $ArticleBackendObject->ArticleDeleteAttachment(
    ArticleID => $Articles[0]->{ArticleID},
    UserID    => 1,
);

# get queued data for indexing
$Queue = $SearchChildObject->IndexObjectQueueGet(
    Index => 'Ticket',
);

$Self->False(
    $Queue,
    "ArticleDeleteAttachment event when attachment indexing is disabled check, queue not created/exists, sql.",
);

1;

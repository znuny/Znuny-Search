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

my $TicketObject              = $Kernel::OM->Get('Kernel::System::Ticket');
my $StateObject               = $Kernel::OM->Get('Kernel::System::State');
my $PriorityObject            = $Kernel::OM->Get('Kernel::System::Priority');
my $HelperObject              = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $SearchObject              = $Kernel::OM->Get('Kernel::System::Search');
my $SearchChildObject         = $Kernel::OM->Get('Kernel::System::Search::Object');
my $ZnunyHelperObject         = $Kernel::OM->Get('Kernel::System::ZnunyHelper');
my $ConfigObject              = $Kernel::OM->Get('Kernel::Config');
my $DBObject                  = $Kernel::OM->Get('Kernel::System::DB');
my $UserObject                = $Kernel::OM->Get('Kernel::System::User');
my $CustomerUserObject        = $Kernel::OM->Get('Kernel::System::CustomerUser');
my $CustomerCompanyObject     = $Kernel::OM->Get('Kernel::System::CustomerCompany');
my $ServiceObject             = $Kernel::OM->Get('Kernel::System::Service');
my $TypeObject                = $Kernel::OM->Get('Kernel::System::Type');
my $QueueObject               = $Kernel::OM->Get('Kernel::System::Queue');
my $SLAObject                 = $Kernel::OM->Get('Kernel::System::SLA');
my $JSONObject                = $Kernel::OM->Get('Kernel::System::JSON');
my $ArticleObject             = $Kernel::OM->Get('Kernel::System::Ticket::Article');
my $GroupObject               = $Kernel::OM->Get('Kernel::System::Group');
my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

# just for gitlab pipeline to pass this test
if ( !$SearchObject->{ConnectObject} ) {
    return 1;
}

my $IndexName = 'FAQ';

my $ActiveEngine = $SearchObject->{Config}->{ActiveEngine};

$Self->True(
    $ActiveEngine,
    "Active engine ($SearchObject->{Config}->{ActiveEngine}) exists, search engine.",
);

return if !$ActiveEngine;

my $StartQueuedIndexation = sub {
    my ( $Self, %Param ) = @_;

    my $CommandObject
        = $Kernel::OM->Get("Kernel::System::Console::Command::Maint::Search::${ActiveEngine}::IndexQueueDataProcess");

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

# enable attachment indexation if for some reason it was disabled
$ConfigObject->Set(
    Key   => "SearchEngine::Settings::Index::${ActiveEngine}::$IndexName",
    Value => {
        '000-Framework' => {
            IndexAttachments => 1,
        }
    },
);

my $SearchFAQObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");
my $FAQQueryObject  = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$IndexName");

my $ReindexationStep = 4;

$ConfigObject->Set(
    Key   => 'SearchEngine::Reindexation###Settings',
    Value => {
        ReindexationStep => $ReindexationStep,
    },
);

my $Object = {
    Basic => {
        User => {
            ID => 1,
        },
        Category => {
            Name   => 'some-category',
            Groups => [
                {
                    Name => 'group-test-1',
                },
                {
                    Name => 'group-test-2',
                },
                {
                    Name => 'group-test-3',
                },
                {
                    Name         => 'group-test-4',
                    NoPermission => 1,
                },
                {
                    Name         => 'group-test-5',
                    NoPermission => 1,
                }
            ],
        },
        State => {
            Name => 'some-state',
        },
        Language => {
            Name => 'language-test',
        },
        Title => {
            Value => 'some-title',
        },
        Number => {
            Value => '13402',
        },
        Keywords => {
            Value => 'keyword1 keyword2',
        },
        Field1 => {
            Value => 'field1-test',
        },
        Field2 => {
            Value => 'field2-test',
        },
        Field3 => {
            Value => 'field3-test',
        },
        Field4 => {
            Value => 'field4-test',
        },
        Field5 => {
            Value => 'field5-test',
        },
        Field6 => {
            Value => 'field6-test',
        },
        Approved => {
            Value => '1',
        },
        ContentType => {
            Value => 'text/plain',
        },
    }
};

my $QueueDeleteSuccess = $SearchChildObject->IndexObjectQueueDelete(
    Index => 'FAQ',
);

# TODO

# add category
my $CategoryName = $Object->{Basic}->{Category}->{Name};
my $CategoryID   = $FAQObject->CategoryAdd(
    Name     => $CategoryName,
    ParentID => 0,
    ValidID  => 1,
    UserID   => $Object->{Basic}->{User}->{ID},
);

$Object->{Basic}->{Category}->{ID} = $CategoryID;

$Self->True(
    $CategoryID,
    "Basic Category (id: $CategoryID, name: $CategoryName) created/exists, sql.",
);

# create groups with & without permissions to FAQ
my %SetCategoryGroup;
for my $Group ( @{ $Object->{Basic}->{Category}->{Groups} } ) {
    my $ID = $GroupObject->GroupAdd(
        Name    => $Group->{Name},
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $ID,
        "Basic Category group (id: $ID, name: $Group->{Name}) created/exists, sql.",
    );

    $Group->{ID} = $ID;
    push @{ $SetCategoryGroup{PermissionGrant} },  $ID if !$Group->{NoPermission};
    push @{ $SetCategoryGroup{PermissionReject} }, $ID if $Group->{NoPermission};
}

# set category group
my $Success = $FAQObject->SetCategoryGroup(
    CategoryID => $CategoryID,
    GroupIDs   => $SetCategoryGroup{PermissionGrant},
    UserID     => 1,
);

$Self->True(
    $Success,
    "Basic Category groups assigned, sql.",
);

# create test user with granted access to faq
my $UserIDWithGrantedAccess = $UserObject->UserAdd(
    UserFirstname => '__testuser-firstname',
    UserLastname  => '__testuser-lastname',
    UserLogin     => '__testuser-login',
    UserEmail     => '__testuser-mail@mail.com',
    ValidID       => 1,
    ChangeUserID  => 1,
);

# grant user permissions to Category groups
for my $GroupID ( @{ $SetCategoryGroup{PermissionGrant} } ) {

    $GroupObject->PermissionGroupUserAdd(
        GID        => $GroupID,
        UID        => $UserIDWithGrantedAccess,
        Permission => {
            ro        => 1,
            move_into => 1,
            create    => 1,
            note      => 1,
            owner     => 1,
            priority  => 1,
            rw        => 1,
        },
        UserID => 1,
    );
}

# create test user with no access to faq
my $UserIDWithNoAccess = $UserObject->UserAdd(
    UserFirstname => '__testuser-firstname2',
    UserLastname  => '__testuser-lastname2',
    UserLogin     => '__testuser-login2',
    UserEmail     => '__testuser-mail@mail.com2',
    ValidID       => 1,
    ChangeUserID  => 1,
);

# grant user permissions to Category groups
for my $GroupID ( @{ $SetCategoryGroup{PermissionReject} } ) {
    $GroupObject->PermissionGroupUserAdd(
        GID        => $GroupID,
        UID        => $UserIDWithNoAccess,
        Permission => {
            ro        => 1,
            move_into => 1,
            create    => 1,
            note      => 1,
            owner     => 1,
            priority  => 1,
            rw        => 1,
        },
        UserID => 1,
    );
}

my $StateName = $Object->{Basic}->{State}->{Name};
$Success = $FAQObject->StateAdd(
    Name   => $StateName,
    TypeID => 1,
    UserID => $Object->{Basic}->{User}->{ID},
);

my %States = $FAQObject->StateList(
    UserID => 1,
);

my %StatesReverse = reverse %States;

$Object->{Basic}->{State}->{ID} = $StatesReverse{$StateName};

$Self->True(
    $Success,
    "Basic State success: $Success (name: $StateName), created/exists, sql.",
);

my $LanguageName = $Object->{Basic}->{Language}->{Name};
$Success = $FAQObject->LanguageAdd(
    Name   => $LanguageName,
    UserID => 1,
);

my %Languages = $FAQObject->LanguageList(
    UserID => 1,
);

my %ReverseLanguages = reverse %Languages;

$Object->{Basic}->{Language}->{ID} = $ReverseLanguages{$LanguageName};

$Self->True(
    $Success,
    "Basic Language success: $Success (name: $LanguageName), created/exists, sql.",
);

my %BasicObjectProperties = (
    Title       => $Object->{Basic}->{Title}->{Value},
    CategoryID  => $Object->{Basic}->{Category}->{ID},
    StateID     => $Object->{Basic}->{State}->{ID},
    LanguageID  => $Object->{Basic}->{Language}->{ID},
    Number      => $Object->{Basic}->{Number}->{Value},
    Keywords    => $Object->{Basic}->{Keywords}->{Value},
    Field1      => $Object->{Basic}->{Field1}->{Value},
    Field2      => $Object->{Basic}->{Field2}->{Value},
    Field3      => $Object->{Basic}->{Field3}->{Value},
    Field4      => $Object->{Basic}->{Field4}->{Value},
    Field5      => $Object->{Basic}->{Field5}->{Value},
    Field6      => $Object->{Basic}->{Field6}->{Value},
    Approved    => $Object->{Basic}->{Approved}->{Value},
    ValidID     => 1,
    ContentType => $Object->{Basic}->{ContentType}->{Value},
    UserID      => $Object->{Basic}->{User}->{ID},
);

my $ItemID = $FAQObject->FAQAdd(%BasicObjectProperties);

$Self->True(
    $ItemID,
    "FAQ: $ItemID, created/exists, sql.",
);

# test indexation queue
my $IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

my $ExpectedResult = {
    ObjectID => {
        $ItemID => [
            {
                Data      => undef,
                Operation => 'ObjectIndexAdd',
                ID        => $IndexationData->{ObjectID}->{$ItemID}->[0]->{ID},
                Order     => undef,
            },
        ],
    },
    LastOrder => 0
};

$Self->IsDeeply(
    $IndexationData,
    $ExpectedResult,
    "Basic FAQ add case of indexation queue: $ItemID, updated, sql.",
);

$Success = $FAQObject->FAQUpdate(
    %BasicObjectProperties,
    Title  => 'updated-title',
    ItemID => $ItemID,
);

$Self->True(
    $Success,
    "Basic FAQ title update action: $ItemID, updated, sql.",
);

# test indexation queue for update
$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

# check if indexation update was added
# it shouldn't be as whole faq indexation is included in ObjectIndexAdd operation
$Self->IsDeeply(
    $IndexationData,
    $ExpectedResult,
    "Basic FAQ add->update(title) case of indexation queue: $ItemID, updated, sql.",
);

$Success = $FAQObject->FAQDelete(
    ItemID => $ItemID,
    UserID => 1,
);

$Self->True(
    $Success,
    "Basic FAQ delete action: $ItemID, deleted, sql.",
);

# test indexation queue for delete
$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

$Self->False(
    $IndexationData,
    "Basic FAQ add->update(title)->delete case of indexation queue: $ItemID, deleted, sql.",
);

# now test attachments on new FAQ object
$ItemID = $FAQObject->FAQAdd(%BasicObjectProperties);

$Self->True(
    $ItemID,
    "Second FAQ: $ItemID, created/exists, sql.",
);

# now test attachments on new FAQ object
$ItemID = $FAQObject->FAQAdd(%BasicObjectProperties);

my $AttachmentID = $FAQObject->AttachmentAdd(
    ItemID  => $ItemID,
    Content => 'test1
test1
test1test1test1',
    ContentType => 'text/plain',
    Filename    => 'test1.txt',
    UserID      => 1,
);

# test indexation queue for attachment add after base object add
$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

$ExpectedResult = {
    ObjectID => {
        $ItemID => [
            {
                Data      => undef,
                Operation => 'ObjectIndexAdd',
                ID        => $IndexationData->{ObjectID}->{$ItemID}->[0]->{ID},
                Order     => undef,
            },
        ],
    },
    LastOrder => 0
};

# check if indexation of attachment was added
# it shouldn't be as attachment indexation is included in ObjectIndexAdd operation of standard FAQ object
$Self->IsDeeply(
    $IndexationData,
    $ExpectedResult,
    "Basic FAQ attachment add(FAQ)->add(Attachment) case of indexation queue: $ItemID, updated, sql.",
);

$Success = $FAQObject->AttachmentDelete(
    ItemID => $ItemID,
    FileID => $AttachmentID,
    UserID => 1,
);

$Self->True(
    $Success,
    "Basic FAQ attachment delete action: $ItemID (attachment id: $AttachmentID), deleted, sql.",
);

# test indexation queue for attachment delete after base object add
$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

# check if indexation of attachment was deleted
# it shouldn't be as attachment indexation is included in ObjectIndexAdd operation of standard FAQ object
# and ObjectIndexAdd will always index only existing attachments
$Self->IsDeeply(
    $IndexationData,
    $ExpectedResult,
    "Basic FAQ attachment add(FAQ)->add(Attachment)->delete(Attachment) case of indexation queue: $ItemID, updated, sql.",
);

# finally index data on the engine side
$StartQueuedIndexation->();

# base FAQ search
my $Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID => $ItemID,
        UserID => $UserIDWithGrantedAccess,    # test permissions
    },
    Fields => [ [ 'FAQ_*', 'Attachment_*' ] ]
);

# do not test some properties as
# Number will not be set as the one provided in the FAQAdd param
# Changed, ChangedBy, Created, CreatedBy are params that are dynamically created
# Name is a param that autogenerates
for my $Property (qw(Changed ChangedBy Created CreatedBy Name Number)) {
    delete $Search->{FAQ}->[0]->{$Property};
}

my %BasicPropertiesToTest = %BasicObjectProperties;

# some parameters needs to be converted to integers for compatibility
for my $Property (qw(Approved CategoryID LanguageID StateID)) {
    $BasicPropertiesToTest{$Property} = int( $BasicPropertiesToTest{$Property} );
}

for my $Property (qw(UserID Number)) {
    delete $BasicPropertiesToTest{$Property};
}

my $SearchExpectedResult = {
    FAQ => [
        {
            ItemID  => int($ItemID),
            GroupID => $SetCategoryGroup{PermissionGrant},
            %BasicPropertiesToTest,
        },
    ],
};

$Self->IsDeeply(
    $Search,
    $SearchExpectedResult,
    "Base FAQ search response check - with permissions.",
);

# again search same FAQ, but with user that does not have correct permissions
$Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID => $ItemID,
        UserID => $UserIDWithNoAccess,    # test permissions
    },
    Fields => [ [ 'FAQ_*', 'Attachment_*' ] ]
);

$SearchExpectedResult = { FAQ => [] };

$Self->IsDeeply(
    $Search,
    $SearchExpectedResult,
    "Base FAQ search response check - without permissions.",
);

# change category groups so that user with no access have access
# and user that had access does not have it anymore
$Success = $FAQObject->SetCategoryGroup(
    CategoryID => $CategoryID,
    GroupIDs   => $SetCategoryGroup{PermissionReject},
    UserID     => 1,
);

$Self->True(
    $Success,
    "Category groups re-assigned, sql.",
);

$StartQueuedIndexation->();

$Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID => $ItemID,
        UserID => $UserIDWithNoAccess,    # test permissions
    },
    Fields => [ [ 'FAQ_*', 'Attachment_*' ] ]
);

# user that did not had any permissions initially should have it now
$Self->True(
    scalar @{ $Search->{FAQ} },
    "Base FAQ search response check after changed no permissions to permissions access - user without permissions.",
);

# add two attachments to FAQ
my @AttachmentIDs;
for ( 1 .. 2 ) {
    $AttachmentID = $FAQObject->AttachmentAdd(
        ItemID  => $ItemID,
        Content => 'test1
    test1
    test1test1test1',
        ContentType => 'text/plain',
        Filename    => 'test1.txt',
        UserID      => 1,
    );

    $Self->True(
        $AttachmentID,
        "Basic FAQ attachment add action: $ItemID (attachment id: $AttachmentID), added, sql.",
    );

    push @AttachmentIDs, $AttachmentID;
}

$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

my $ExpectedAttachmentDataToAdd = \@AttachmentIDs;

$Self->IsDeeply(
    $IndexationData->{ObjectID}->{$ItemID}->[0]->{Data}->{AddAttachment},
    $ExpectedAttachmentDataToAdd,
    "Add two attachments indexation queue check, sql",
);

$FAQObject->AttachmentDelete(
    ItemID => $ItemID,
    FileID => $AttachmentIDs[-1],
    UserID => 1,
);

$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

$ExpectedAttachmentDataToAdd = [ $AttachmentIDs[0] ];

$Self->IsDeeply(
    $IndexationData->{ObjectID}->{$ItemID}->[0]->{Data}->{AddAttachment},
    $ExpectedAttachmentDataToAdd,
    "Add two attachments, then delete second indexation queue check, sql",
);

$Success = $FAQObject->FAQUpdate(
    %BasicObjectProperties,
    Title  => 'updated-title',
    ItemID => $ItemID,
);

# test indexation queue for attachment delete after base object add
$IndexationData = $SearchChildObject->IndexObjectQueueGet(
    Index    => $IndexName,
    ObjectID => [$ItemID],
);

$StartQueuedIndexation->();

# search FAQ again
$Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID => $ItemID,
        Title  => 'updated-title',
        UserID => $UserIDWithGrantedAccess,
    },
    Fields => [ [qw(Attachment_Filename Attachment_ContentType Attachment_AttachmentContent )] ]
);

my $ExpectedAttachmentResult = {
    FAQ => [
        {
            Attachments => [
                {
                    AttachmentContent => 'test1
    test1
    test1test1test1',
                    ContentType => 'text/plain',
                    Filename    => 'test1.txt'
                }
            ]
        }
    ]
};

$Self->IsDeeply(
    $Search,
    $ExpectedAttachmentResult,
    "Updated FAQ with indexated attachment check with pipeline success, engine",
);

my $TestDFName = 'testdynamicfieldname';
my $DFID       = $DynamicFieldObject->DynamicFieldAdd(
    InternalField => 0,
    Name          => $TestDFName,
    Label         => 'test-description',
    Config        => {},
    FieldOrder    => 999,
    FieldType     => 'Text',
    ObjectType    => 'FAQ',
    ValidID       => 1,
    UserID        => 1,
);

$Self->True(
    $DFID,
    "New Dynamic field create action (id: $DFID, name: $TestDFName) created/exists, sql.",
);

my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
    Name => $TestDFName,
);

my $TestDFValue = 'test-value';
my $Value       = $DynamicFieldBackendObject->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $ItemID,
    Value              => $TestDFValue,
    UserID             => 1,
);

$StartQueuedIndexation->();

# search FAQ again
$Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID                     => $ItemID,
        "DynamicField_$TestDFName" => $TestDFValue,
        UserID                     => $UserIDWithGrantedAccess,
    },
    Fields => [ [ 'FAQ_ItemID', "FAQ_DynamicField_$TestDFName" ] ]
);

$ExpectedResult = {
    FAQ => [
        {
            ItemID                     => int($ItemID),
            "DynamicField_$TestDFName" => $TestDFValue
        }
    ]
};

$Self->IsDeeply(
    $Search,
    $ExpectedResult,
    "FAQ dynamic field update response check, engine",
);

my $NewTestDFName = 'newdfname';

# check if dynamic field name will be changed inside faq object if dynamic field name object
# will be changed in the system
$Success = $DynamicFieldObject->DynamicFieldUpdate(
    ID         => $DFID,
    Name       => $NewTestDFName,
    Label      => 'a description',
    FieldOrder => 999,
    FieldType  => 'Text',
    ObjectType => 'FAQ',
    Config     => {},
    ValidID    => 1,
    UserID     => 1,
);

$StartQueuedIndexation->();

$Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID => $ItemID,
        UserID => $UserIDWithGrantedAccess,
    },

    # search by "FAQ_DynamicField_$TestDFName" on purpose to check if it exists anymore
    Fields => [ [ 'FAQ_ItemID', "FAQ_DynamicField_$NewTestDFName", "FAQ_DynamicField_$TestDFName" ] ]
);

$ExpectedResult = {
    FAQ => [
        {
            ItemID                        => $ItemID,
            "DynamicField_$NewTestDFName" => $TestDFValue,
        }
    ]
};

$Self->IsDeeply(
    $Search,
    $ExpectedResult,
    "FAQ dynamic field name update response check, engine",
);

# check if dynamic field will be deleted inside FAQ object if dynamic field object
# will be deleted from the system
my $ValuesDeleteSuccess = $DynamicFieldBackendObject->AllValuesDelete(
    DynamicFieldConfig => $DynamicFieldConfig,
    UserID             => 1,
);

$Self->True(
    $ValuesDeleteSuccess,
    "New Dynamic field delete values action (id: $DFID, name: $NewTestDFName), sql.",
);

$Success = $DynamicFieldObject->DynamicFieldDelete(
    ID     => $DFID,
    UserID => 1,
);

$Self->True(
    $Success,
    "New Dynamic field delete action (id: $DFID, name: $NewTestDFName), sql.",
);

$StartQueuedIndexation->();

$Search = $SearchObject->Search(
    Objects     => ["FAQ"],
    QueryParams => {
        ItemID => $ItemID,
        UserID => $UserIDWithGrantedAccess,
    },
    Fields => [ [ 'FAQ_ItemID', "FAQ_DynamicField_$NewTestDFName" ] ]
);

$ExpectedResult = {
    FAQ => [
        {
            ItemID => $ItemID,
        }
    ]
};

$Self->IsDeeply(
    $Search,
    $ExpectedResult,
    "FAQ dynamic field delete response check, engine",
);
1;

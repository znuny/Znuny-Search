# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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

my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
my $StateObject        = $Kernel::OM->Get('Kernel::System::State');
my $PriorityObject     = $Kernel::OM->Get('Kernel::System::Priority');
my $Helper             = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $SearchObject       = $Kernel::OM->Get('Kernel::System::Search');
my $ZnunyHelperObject  = $Kernel::OM->Get('Kernel::System::ZnunyHelper');
my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Ticket');

# check if there is connection with search engine
$Self->True(
    $SearchObject->{ConnectObject},
    "Connection to engine - Exists"
);

if ( !$SearchObject->{ConnectObject} ) {
    return;
}

my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

# delete all tickets/articles sql
# can be commented when executed once
$DBObject->Do(
    SQL => "DELETE FROM article_search_index",
);
$DBObject->Do(
    SQL => "DELETE FROM article_data_mime",
);
$DBObject->Do(
    SQL => "DELETE FROM article_data_mime_plain",
);
$DBObject->Do(
    SQL => "DELETE FROM article_flag",
);
$DBObject->Do(
    SQL => "DELETE FROM ticket_history",
);
$DBObject->Do(
    SQL => "DELETE FROM ticket_flag",
);
$DBObject->Do(
    SQL => "DELETE FROM article_data_mime_attachment",
);
$DBObject->Do(
    SQL => "DELETE FROM article_data_mime_send_error",
);
$DBObject->Do(
    SQL => "DELETE FROM article",
);
$DBObject->Do(
    SQL => "DELETE FROM ticket",
);

# delete all tickets engine side
my $Result = $SearchObject->IndexClear(
    Index => 'Ticket',
);

$Result = $SearchObject->IndexInit(
    Index => 'Ticket',
);

my %BasicTicketProperties = (
    Title        => 'TicketTitle',
    Queue        => 'Raw',
    Lock         => 'unlock',
    PriorityID   => 1,
    State        => 'new',
    CustomerID   => '123456',
    CustomerUser => '',
    OwnerID      => 1,
    UserID       => 1,
);

# get table column names to know what ticket should contain in the mapping
my @SQLTableColumnNames;
$DBObject->Prepare(
    SQL => "SHOW COLUMNS FROM ticket",

# another sql query variation: SELECT distinct COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'ticket';
# but seems to return deleted columns before
);

while ( my @Row = $DBObject->FetchrowArray() ) {
    push @SQLTableColumnNames, $Row[0],;
}

# get data about fields for ticket object
my $TicketFields           = $SearchTicketObject->{Fields};
my %TicketValidFields      = ();
my %TicketValidFieldsNames = ();

my %TicketRealFieldNames;
my %TicketFieldMapping;
my $CreateNewTickets = 1;

if ( IsHashRefWithData($TicketFields) ) {

    # set real name columns as a keys for further processing
    for my $FieldName ( sort keys %{$TicketFields} ) {
        if ( $TicketFields->{$FieldName}->{ColumnName} ) {
            $TicketRealFieldNames{ $TicketFields->{$FieldName}->{ColumnName} } = 1;
            $TicketValidFields{$FieldName}                                     = $TicketFields->{$FieldName};
            $TicketValidFieldsNames{$FieldName}                                = 1;
        }
        else {
            undef $CreateNewTickets;
        }
    }

    # check if all table columns are supported in the field mapping
    for my $SQLColumnName (@SQLTableColumnNames) {
        $Self->True(
            $TicketRealFieldNames{$SQLColumnName},
            "Ticket column name support for sql and search engine - $SQLColumnName.",
        );
        if ( $TicketRealFieldNames{$SQLColumnName} ) {
            delete $TicketRealFieldNames{$SQLColumnName};
        }
    }

    # check if there is any column that is supported but does not exists
    # in the sql table
    for my $AdditionalColumn ( sort keys %TicketRealFieldNames ) {
        $Self->False(
            $AdditionalColumn,
            "Ticket column defined in sql/engine that does not exists in sql table: $AdditionalColumn"
        );
    }
}

# create basic ticket
my $TicketID = $TicketObject->TicketCreate(
    %BasicTicketProperties,
);

$Self->True(
    $TicketID,
    "Basic ticket created, sql.",
);

# check if ticket have specified supported operators
my $TicketSupportedOperators = $SearchTicketObject->{SupportedOperators};
my $SupportedOperatorsExists = IsHashRefWithData($TicketSupportedOperators);

$Self->True(
    $SupportedOperatorsExists,
    "Ticket index supported operators exists.",
);

my %PossibleTypes = (
    "Date"    => 1,
    "Integer" => 1,
    "Text"    => 1,
    "String"  => 1,
    "Long"    => 1,
);

# continue only when supported operators exists
if ($SupportedOperatorsExists) {

    for my $Key ( sort keys %TicketValidFields ) {
        $Self->True(
            $PossibleTypes{ $TicketValidFields{$Key}->{Type} },
            "Ticket Field: $Key valid type check.",
        );

        if ( !$PossibleTypes{ $TicketValidFields{$Key}->{Type} } ) {

            # valid fields that does not contain valid types are invalid
            # delete them to do not show so many errors in the later part
            # of the test
            delete $TicketValidFields{$Key};

            # additionally ignore later part of the test with creating new tickets
            # as first all fields needs to be valid
            undef $CreateNewTickets;
        }
    }

    # basic ticket id check
    if ($TicketID) {

        # search via engine
        my $EngineResult = $SearchObject->Search(
            Objects     => ['Ticket'],
            QueryParams => {
                TicketID => $TicketID,
            },
        );

        $SearchObject->{Fallback} = 1;

        # search via fallback mechanism
        my $FallbackResult = $SearchObject->Search(
            Objects     => ['Ticket'],
            QueryParams => {
                TicketID => $TicketID,
            },
        );

        # compare them
        $Self->IsDeeply(
            $EngineResult,
            $FallbackResult,
            "(Engine => SQL response) Basic Ticket (id: $TicketID) check:\n" .
                "field to check     - TicketID,\n" .
                "QueryParamValue    - $TicketID,\n"
        );

        # revert fallback flag
        $SearchObject->{Fallback} = 0;

        # single ticket object data should be found in the data structure
        # for both fallback and engine
        # if it's true, then compare them with column names from the Ticket
        # module schema
        if ( $EngineResult->{Ticket}->[0] && $FallbackResult->{Ticket}->[0] ) {
            my %EngineResponseKeys   = %{ $EngineResult->{Ticket}->[0] };
            my %FallbackResponseKeys = %{ $FallbackResult->{Ticket}->[0] };

            for my $Field ( sort keys %EngineResponseKeys ) {
                $EngineResponseKeys{$Field} = 1;
            }
            for my $Field ( sort keys %FallbackResponseKeys ) {
                $FallbackResponseKeys{$Field} = 1;
            }

            $Self->IsDeeply(
                \%TicketValidFieldsNames,
                \%EngineResponseKeys,
                "Basic ticket engine response object column names <=> defined in module schema columns names check",
            );

            $Self->IsDeeply(
                \%TicketValidFieldsNames,
                \%FallbackResponseKeys,
                "Basic ticket fallback response object column names <=> defined in module schema columns names check",
            );
        }
    }

    # depends on if all ticket fields are valid
    if ($CreateNewTickets) {

        # define new tickets to create & test
        my @TicketMapping = (
            {
                TestName     => 'Empty title',
                InsertParams => {                # create ticket properties
                    %BasicTicketProperties,
                    Title => '',
                },
                FieldsToCheck => ['Title'],
            },
        );

        my %CheckedFields;

        TICKET:
        for my $TicketToCreate (@TicketMapping) {
            my $TicketID = $TicketObject->TicketCreate(
                %{ $TicketToCreate->{InsertParams} }
            );

            $TicketToCreate->{ID} = $TicketID;

            my $Result = $SearchObject->Search(
                Objects     => ['Ticket'],
                QueryParams => {
                    TicketID => $TicketID
                }
            );

            $Self->Is(
                $Result->{Ticket}->[0]->{TicketID},
                $TicketID,
                "Ticket created value: $TicketID - SQL, Engine check",
            );

            next TICKET if !$TicketID;
            next TICKET if !IsArrayRefWithData( $TicketToCreate->{FieldsToCheck} );

            my @FieldsToCheck = @{ $TicketToCreate->{FieldsToCheck} };
            my %InsertParams  = %{ $TicketToCreate->{InsertParams} };
            my $Success       = 1;

            # this is more like test ticket create params written
            # wrong, but needs to be checked in order to work
            for my $Field (@FieldsToCheck) {
                my $CheckOk = exists $InsertParams{$Field} ? 1 : 0;
                $Self->True(
                    $CheckOk,
                    "Insert param with fields to check exists check",
                );
                if ( !$CheckOk ) {
                    undef $Success;
                }
            }

            next TICKET if !$Success;

            FIELD_CHECK:
            for my $FieldToCheck ( @{ $TicketToCreate->{FieldsToCheck} } ) {

                # check specified field only once
                if ( !$CheckedFields{ 'Ticket_' . $FieldToCheck } ) {
                    $CheckedFields{ 'Ticket_' . $FieldToCheck } = 1;

                    my $Exists = IsHashRefWithData( $SearchTicketObject->{Fields}->{$FieldToCheck} );

                    $Self->True(
                        $Exists,
                        "Field $FieldToCheck exist in index schema.",
                    );

                    last TICKET if !$Exists;

                    my $FieldType = $SearchTicketObject->{Fields}->{$FieldToCheck}->{Type};

                    $Self->True(
                        $FieldType,
                        "Field type $FieldToCheck exist in index schema.",
                    );

                    last TICKET if !$FieldType;

                    my $ColumnName = $SearchTicketObject->{Fields}->{$FieldToCheck}->{ColumnName};

                    $Self->True(
                        $FieldType,
                        "Field column name $FieldToCheck exists in index schema.",
                    );

                    last TICKET if !$FieldType;

                    my $SupportedOperatorsForColumn = $SearchTicketObject->{SupportedOperators}->{$FieldType};

                    $Self->True(
                        $SupportedOperatorsForColumn,
                        "Field column name $FieldToCheck supported operator check.",
                    );

                    last TICKET if !$FieldType;
                }

                my $FieldType                   = $SearchTicketObject->{Fields}->{$FieldToCheck}->{Type};
                my $ColumnName                  = $SearchTicketObject->{Fields}->{$FieldToCheck}->{ColumnName};
                my $SupportedOperatorsForColumn = $SearchTicketObject->{SupportedOperators}->{$FieldType};

                my @Fields;
                my @FieldsAdd;

                # let's test fields param for search call in 3 parts
                my $ValidFieldNamesCount  = keys %TicketValidFieldsNames;
                my @SortedValidFieldNames = sort keys %TicketValidFieldsNames;
                my $Index                 = 0;
                push @Fields, [];
                if ( $ValidFieldNamesCount >= 3 ) {

                    # calculate step for slices
                    my $Step = int( $ValidFieldNamesCount / 3 );
                    for ( 1 .. 2 ) {
                        push @FieldsAdd, @SortedValidFieldNames[ $Index .. $Step + $Index - 1 ];
                        push @Fields, [@FieldsAdd];
                        $Index += $Step;
                    }

                    # third part will contain all field names
                    push @Fields, [@SortedValidFieldNames];
                }
                else {
                    # if less than 3 valid columns exists then add single
                    # column to fields
                    for my $FieldName (@SortedValidFieldNames) {
                        push @FieldsAdd, $FieldName;
                        push @Fields, [@FieldsAdd];
                    }
                }

                # add testing first column found with different data type
                my @SortBy;
                my %SortByType;
                for my $Field ( sort keys %TicketValidFields ) {
                    my $FieldType = $TicketValidFields{$Field}->{Type};
                    if ( !$SortByType{$FieldType} ) {
                        $SortByType{$FieldType} = 1;
                        push @SortBy, $Field;
                    }
                }

                # define limit for search call
                my @Limit = ( '', '0', '1', '2' );

                next FIELD_CHECK if !IsHashRefWithData( $SupportedOperatorsForColumn->{Operator} );

                OPERATOR:

                # check every possible operator
                for my $Operator ( sort keys %{ $SupportedOperatorsForColumn->{Operator} } ) {
                    next OPERATOR if !$SupportedOperatorsForColumn->{Operator}->{$Operator};
                    RESULT_TYPE:

                    # check default result types
                    for my $ResultType (qw(HASH ARRAY COUNT)) {

                        # check SortBy columns that have different type
                        # as there is no need to sort by every column
                        SORT_BY:
                        for my $SortBy (@SortBy) {

                            # by default there are only two possible
                            # order by parameters
                            ORDER_BY:
                            for my $OrderBy (qw(Down Up)) {
                                LIMIT:
                                for my $Limit (@Limit) {
                                    FIELDS:
                                    for my $Fields (@Fields) {

                                        # search call for engine
                                        my $EngineSearch = $SearchObject->Search(
                                            Objects     => ["Ticket"],
                                            QueryParams => {
                                                $FieldToCheck => {
                                                    Operator => $Operator,
                                                    Value    => $InsertParams{$FieldToCheck}
                                                },
                                            },
                                            ResultType => $ResultType,
                                            SortBy     => [$SortBy],
                                            OrderBy    => $OrderBy,
                                            Limit      => $Limit,
                                            Fields     => [$Fields],
                                            Silent     => 1,
                                        );

                                        # search call for fallback
                                        $SearchObject->{Fallback} = 1;
                                        my $FallbackSearch = $SearchObject->Search(
                                            Objects     => ["Ticket"],
                                            QueryParams => {
                                                $FieldToCheck => $InsertParams{$FieldToCheck},
                                            },
                                            ResultType => $ResultType,
                                            SortBy     => [$SortBy],
                                            OrderBy    => $OrderBy,
                                            Limit      => $Limit,
                                            Fields     => [$Fields],
                                            Silent     => 1,
                                        );
                                        my $FieldsStrg = join ", ", @{$Fields};

                                        # revert fallback flag for another iteration
                                        $SearchObject->{Fallback} = 0;

                                        # show all important data about test
                                        my $IsDeeplyResult = $Self->IsDeeply(
                                            $EngineSearch,
                                            $FallbackSearch,
                                            "(Engine => SQL response) Ticket engine eq fallback result:\n" .
                                                "field to check     - $FieldToCheck,\n" .
                                                "QueryParamOperator - $Operator,\n" .
                                                "QueryParamValue    - $InsertParams{$FieldToCheck},\n" .
                                                "SortBy             - $SortBy,\n" .
                                                "OrderBy            - $OrderBy,\n" .
                                                "Limit              - $Limit,\n" .
                                                "Fields             - $FieldsStrg.\n"
                                        );

                                        # break due to the fact that otherwise
                                        # it would be too much not passed tests
                                        # as there are many combinations checked
                                        # and output could be hard to read
                                        # so first fix latest test and then re-run
                                        last TICKET if ( !$IsDeeplyResult );
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

1;

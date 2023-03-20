# --
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::CustomerUser::Elasticsearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use parent qw (Kernel::System::CustomerUser::DB);

our @ObjectDependencies = (
    'Kernel::System::DateTime',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::Valid',
    'Kernel::System::JSON',
    'Kernel::System::Search',
    'Kernel::System::Search::Object::Default::CustomerUser',
    'Kernel::System::Search::Object::Query::CustomerUser',
);

sub CustomerSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject             = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::CustomerUser');

    # use db search when Elasticsearch is not available
    return $Self->SUPER::CustomerSearch(%Param)
        if $SearchObject->{Fallback} || !$SearchCustomerUserObject->{ActiveDBBackend}->{ValidBackend};

    my %Users;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    my $LogObject                     = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchQueryCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::CustomerUser');
    my $DynamicFieldObject            = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject     = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $EngineObject                  = $SearchObject->{EngineObject};
    my $MappingObject                 = $SearchObject->{MappingIndexObject}->{CustomerUser};

    # check needed stuff
    if (
        !$Param{Search}
        && !$Param{UserLogin}
        && !$Param{PostMasterSearch}
        && !$Param{CustomerID}
        && !$Param{CustomerIDRaw}
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Search, UserLogin, PostMasterSearch, CustomerIDRaw or CustomerID!',
        );
        return;
    }

    # check cache
    my $CacheKey = join '::', map { $_ . '=' . $Param{$_} } sort keys %Param;

    if ( $Self->{CacheObject} ) {
        my $Users = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType} . '_CustomerSearch',
            Key  => $CacheKey . '::Elasticsearch',
        );
        return %{$Users} if ref $Users eq 'HASH';
    }

    my $CustomerUserListFields = $Self->{CustomerUserMap}->{CustomerUserListFields};
    if ( !IsArrayRefWithData($CustomerUserListFields) ) {
        $CustomerUserListFields = [ 'first_name', 'last_name', 'email', ];
    }

    # remove dynamic field names that are configured in CustomerUserListFields
    # as they cannot be handled here
    my @CustomerUserListFieldsWithoutDynamicFields
        = grep { !exists $Self->{ConfiguredDynamicFieldNames}->{$_} } @{$CustomerUserListFields};

    my @Fields        = ( $Self->{CustomerKey}, @CustomerUserListFieldsWithoutDynamicFields );
    my $IndexRealName = $SearchCustomerUserObject->{Config}->{IndexRealName};

    # use query builder
    my $EngineQueryHelperObj = $SearchQueryCustomerUserObject->EngineQueryHelperObjCreate(
        IndexName => 'CustomerUser',
        Query     => {
            Method => 'GET',
            Path   => "$IndexRealName/_search",
            Body   => {
                _source => 'false',
                fields  => \@Fields
            }
        },
    );

    my $InvertedFields = $SearchCustomerUserObject->FieldsInvertedFormat();

    my %DatabaseFieldsDef;
    for my $Field (@Fields) {
        $DatabaseFieldsDef{$Field} = $InvertedFields->{$Field};
    }

    if ( $Param{Search} ) {
        if ( !$Self->{CustomerUserMap}->{CustomerUserSearchFields} ) {
            $LogObject->Log(
                Priority => 'error',
                Message =>
                    "Need CustomerUserSearchFields in CustomerUser config, unable to search for '$Param{Search}'!",
            );
            return;
        }

        # remove dynamic field names that are configured in CustomerUserSearchFields
        # as they cannot be retrieved here
        my @CustomerUserSearchFields = grep { !exists $Self->{ConfiguredDynamicFieldNames}->{$_} }
            @{ $Self->{CustomerUserMap}->{CustomerUserSearchFields} };

        if ( $Param{CustomerUserOnly} ) {
            @CustomerUserSearchFields = grep { $_ ne 'customer_id' } @CustomerUserSearchFields;
        }

        push @{ $EngineQueryHelperObj->{Query}->{Body}->{query}->{bool}->{must} }, {
            query_string => {
                fields           => \@CustomerUserSearchFields,
                query            => '*' . $Param{Search} . '*',
                default_operator => 'and',
            },
        };
    }
    elsif ( $Param{PostMasterSearch} ) {
        if ( $Self->{CustomerUserMap}->{CustomerUserPostMasterSearchFields} ) {

            # remove dynamic field names that are configured in CustomerUserPostMasterSearchFields
            # as they cannot be retrieved here
            my @CustomerUserPostMasterSearchFields = grep { !exists $Self->{ConfiguredDynamicFieldNames}->{$_} }
                @{ $Self->{CustomerUserMap}->{CustomerUserPostMasterSearchFields} };

            for my $Field (@CustomerUserPostMasterSearchFields) {
                my $FieldType = $InvertedFields->{$Field}->{Type};

                my $FieldName = $MappingObject->QueryFieldNameBuild(
                    Type => $FieldType,
                    Name => $InvertedFields->{$Field}->{FieldName},
                );

                push @{ $EngineQueryHelperObj->{Query}->{Body}->{query}->{bool}->{must}->[0]->{bool}->{should} }, {
                    term => {
                        $FieldName => $Param{PostMasterSearch},
                    }
                };
            }
        }
    }
    elsif ( $Param{UserLogin} ) {

        my $UserLogin = $Param{UserLogin};

        # check CustomerKey type
        if ( $Self->{CustomerKeyInteger} ) {

            # return if login is no integer
            return if $Param{UserLogin} !~ /^(\+|\-|)\d{1,16}$/;

            $EngineQueryHelperObj->QueryUpdate(
                QueryParams => {
                    $InvertedFields->{ $Self->{CustomerKey} }->{FieldName}, => $UserLogin,
                },
                Strict => 1,
            );
        }
        else {
            $EngineQueryHelperObj->QueryUpdate(
                QueryParams => {
                    $InvertedFields->{ $Self->{CustomerKey} }->{FieldName} => {
                        Operator => 'WILDCARD',
                        Value    => $UserLogin,
                    },
                },
                Strict => 1,
            );
        }
    }
    elsif ( $Param{CustomerID} ) {
        $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $InvertedFields->{ $Self->{CustomerID} }->{FieldName} => {
                    Operator => 'WILDCARD',
                    Value    => $Param{CustomerID},
                },
            },
            Strict => 1,
        );
    }
    elsif ( $Param{CustomerIDRaw} ) {
        $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $InvertedFields->{ $Self->{CustomerKey} }->{FieldName} => $Param{CustomerIDRaw},
            },
            Strict => 1,
        );
    }

    # add valid option
    if ( $Self->{CustomerUserMap}->{CustomerValid} && $Valid ) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

        $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $InvertedFields->{ $Self->{CustomerUserMap}->{CustomerValid} }->{FieldName} =>
                    $ValidObject->ValidIDsGet(),
            },
            Strict => 1,
        );
    }

    $EngineQueryHelperObj->{Query}->{Body}->{size} = $Param{Limit} || $Self->{UserSearchListLimit};

    # return to fallback on any query build error
    return $Self->SUPER::CustomerSearch(%Param) if !$EngineQueryHelperObj->QueryValidate();

    my $Response = $EngineQueryHelperObj->QueryExecute();

    my $Result = $SearchObject->SearchFormat(
        Result     => $Response,
        ResultType => 'ARRAY',
        IndexName  => 'CustomerUser',
        QueryData  => {
            Query => $EngineQueryHelperObj->{Query},
        },
        Fields => \%DatabaseFieldsDef,
    );

    my @CustomerUserData = @{ $Result->{CustomerUser} };

    my $DynamicFieldConfigs = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'CustomerUser',
        Valid      => 1,
    );
    my %DynamicFieldConfigsByName = map { $_->{Name} => $_ } @{$DynamicFieldConfigs};

    my @CustomerUserListFieldsDynamicFields
        = grep { exists $Self->{ConfiguredDynamicFieldNames}->{$_} } @{$CustomerUserListFields};

    CUSTOMERUSERDATA:
    for my $CustomerUserData (@CustomerUserData) {

        my $CustomerKey = delete $CustomerUserData->{ $Self->{CustomerKey} };
        next CUSTOMERUSERDATA if $Users{$CustomerKey};

        my %UserStringParts;

        for my $Field ( sort keys %{$CustomerUserData} ) {
            $UserStringParts{$Field} = $CustomerUserData->{$Field};
        }

        # fetch dynamic field values, if configured
        if (@CustomerUserListFieldsDynamicFields) {
            DYNAMICFIELDNAME:
            for my $DynamicFieldName (@CustomerUserListFieldsDynamicFields) {
                next DYNAMICFIELDNAME if !exists $DynamicFieldConfigsByName{$DynamicFieldName};

                my $Value = $DynamicFieldBackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfigsByName{$DynamicFieldName},
                    ObjectName         => $CustomerKey,
                );

                next DYNAMICFIELDNAME if !defined $Value;

                if ( !IsArrayRefWithData($Value) ) {
                    $Value = [$Value];
                }

                my @Values;
                CURRENTVALUE:
                for my $CurrentValue ( @{$Value} ) {
                    next CURRENTVALUE if !defined $CurrentValue || !length $CurrentValue;

                    my $ReadableValue = $DynamicFieldBackendObject->ReadableValueRender(
                        DynamicFieldConfig => $DynamicFieldConfigsByName{$DynamicFieldName},
                        Value              => $CurrentValue,
                    );

                    next CURRENTVALUE if !IsHashRefWithData($ReadableValue) || !defined $ReadableValue->{Value};

                    my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                        DynamicFieldConfig => $DynamicFieldConfigsByName{$DynamicFieldName},
                        Behavior           => 'IsACLReducible',
                    );
                    if ($IsACLReducible) {
                        my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                            DynamicFieldConfig => $DynamicFieldConfigsByName{$DynamicFieldName},
                        );

                        if (
                            IsHashRefWithData($PossibleValues)
                            && defined $PossibleValues->{ $ReadableValue->{Value} }
                            )
                        {
                            $ReadableValue->{Value} = $PossibleValues->{ $ReadableValue->{Value} };
                        }
                    }

                    push @Values, $ReadableValue->{Value};
                }

                $UserStringParts{$DynamicFieldName} = join ' ', @Values;
            }
        }

        # assemble user string
        my @UserStringParts;
        CUSTOMERUSERLISTFIELD:
        for my $CustomerUserListField ( @{$CustomerUserListFields} ) {
            next CUSTOMERUSERLISTFIELD
                if !exists $UserStringParts{$CustomerUserListField}
                || !defined $UserStringParts{$CustomerUserListField}
                || !length $UserStringParts{$CustomerUserListField};
            push @UserStringParts, $UserStringParts{$CustomerUserListField};
        }

        $Users{$CustomerKey} = join ' ', @UserStringParts;
        $Users{$CustomerKey} =~ s/^(.*)\s(.+?\@.+?\..+?)(\s|)$/"$1" <$2>/;
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType} . '_CustomerSearch',
            Key   => $CacheKey . '::Elasticsearch',
            Value => \%Users,
            TTL   => $Self->{CustomerUserMap}->{CacheTTL},
        );
    }
    return %Users;
}

sub CustomerSearchDetail {
    my ( $Self, %Param ) = @_;

    my $SearchObject             = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::CustomerUser');

    # use db search by default as whole system can't use this function
    # due to performance issues (best to use it for low amount of requests at once)
    return $Self->SUPER::CustomerSearchDetail(%Param)
        if $SearchObject->{Fallback}
        || !$Param{UseAdvancedSearchEngine}
        || !$SearchCustomerUserObject->{ActiveDBBackend}->{ValidBackend};

    my $JSONObject                    = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject                     = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchQueryCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::CustomerUser');

    if ( ref $Param{SearchFields} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "SearchFields must be an array reference!",
        );
        return;
    }

    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    $Param{Limit} //= '';

    # Split the search fields in scalar and array fields, before the diffrent handling.
    my @ScalarSearchFields = grep { 'Input' eq $_->{Type} } @{ $Param{SearchFields} };
    my @ArraySearchFields  = grep { 'Selection' eq $_->{Type} } @{ $Param{SearchFields} };

    # Verify that all passed array parameters contain an arrayref.
    ARGUMENT:
    for my $Argument (@ArraySearchFields) {
        if ( !defined $Param{ $Argument->{Name} } ) {
            $Param{ $Argument->{Name} } ||= [];

            next ARGUMENT;
        }

        if ( ref $Param{ $Argument->{Name} } ne 'ARRAY' ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "$Argument->{Name} must be an array reference!",
            );
            return;
        }
    }

    # Set the default behaviour for the return type.
    my $Result = $Param{Result} || 'ARRAY';

    # Special handling if the result type is 'COUNT'.
    if ( $Result eq 'COUNT' ) {

        # Ignore the parameter 'Limit' when result type is 'COUNT'.
        $Param{Limit} = '';

        # Delete the OrderBy parameter when the result type is 'COUNT'.
        $Param{OrderBy} = [];
    }

    my $InvertedFields = $SearchCustomerUserObject->FieldsInvertedFormat();

    # Define order table from the search fields.
    my %OrderByTable = map { $_->{Name} => $_->{DatabaseField} } @{ $Param{SearchFields} };

    my $IndexRealName   = $SearchCustomerUserObject->{Config}->{IndexRealName};
    my $CustomerKeyType = $InvertedFields->{ $Self->{CustomerKey} }->{Type};
    my $MappingObject   = $SearchObject->{MappingIndexObject}->{CustomerUser};

    my $CustomerKeyAggrName = $MappingObject->QueryFieldNameBuild(
        Type => $CustomerKeyType,
        Name => $Self->{CustomerKey},
    );

    # use query builder
    my $EngineQueryHelperObj = $SearchQueryCustomerUserObject->EngineQueryHelperObjCreate(
        IndexName => 'CustomerUser',
        Query     => {
            Method => 'GET',
            Path   => "$IndexRealName/_search",
            Body   => {
                _source => 'false',
                fields  => [ $Self->{CustomerKey} ],
                aggs    => {
                    unique_cu_ids => {
                        terms => {
                            field => $CustomerKeyAggrName,
                        }
                    }
                }
            }
        },
    );

    FIELD:
    for my $Field (@ArraySearchFields) {

        my $SelectionsData = $Field->{SelectionsData};

        next FIELD if !IsArrayRefWithData( $Param{ $Field->{Name} } );
        next FIELD if $Field->{Name} eq 'ValidID';
        for my $SelectedValue ( @{ $Param{ $Field->{Name} } } ) {

            # Check if the selected value for the current field is valid.
            if ( !$SelectionsData->{$SelectedValue} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "The selected value $Field->{Name} is not valid!",
                );
                return;
            }
        }

        $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $Field->{Name} => $Param{ $Field->{Name} },
            },
            Strict => 1,
        );
    }

    my $DBObject = $Self->{DBObject};

    # Assemble the conditions used in the WHERE clause.
    my @SQLWhere;

    FIELD:
    for my $Field (@ScalarSearchFields) {

        # Search for scalar fields (wildcards are allowed).
        next FIELD if !$Param{ $Field->{Name} };

        # If the field contains more than only *.
        if ( $Param{ $Field->{Name} } !~ m{ \A \** \z }xms ) {
            my $Success = $EngineQueryHelperObj->QueryUpdate(
                QueryParams => {
                    $Field->{Name} => {
                        Operator => 'WILDCARD',
                        Value    => $Param{ $Field->{Name} },
                    }
                },
                Strict => 1,
            );
        }
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFielDBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # Check all configured change dynamic fields, build lookup hash by name.
    my %CustomerUserDynamicFieldName2Config;
    my $CustomerUserDynamicFields = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'CustomerUser',
    );
    for my $DynamicField ( @{$CustomerUserDynamicFields} ) {
        $CustomerUserDynamicFieldName2Config{ $DynamicField->{Name} } = $DynamicField;
    }

    my $SQLDynamicFieldFrom     = '';
    my $SQLDynamicFieldWhere    = '';
    my $DynamicFieldJoinCounter = 1;

    my %DynamicFieldOperatorMap = (
        Equals            => '=',
        Like              => 'WILDCARD',
        GreaterThan       => '>',
        GreaterThanEquals => '>=',
        SmallerThan       => '<',
        SmallerThanEquals => '<=',
    );

    DYNAMICFIELD:
    for my $DynamicField ( @{$CustomerUserDynamicFields} ) {

        my $DynamicFieldFullName = "DynamicField_" . $DynamicField->{Name};
        my $SearchParam          = $Param{$DynamicFieldFullName};

        next DYNAMICFIELD if ( !$SearchParam );
        next DYNAMICFIELD if ( ref $SearchParam ne 'HASH' );

        my $NeedJoin;

        for my $Operator ( sort keys %{$SearchParam} ) {

            my @SearchParams = ( ref $SearchParam->{$Operator} eq 'ARRAY' )
                ? @{ $SearchParam->{$Operator} }
                : ( $SearchParam->{$Operator} );

            my @TextToApply;
            TEXT:
            for my $Text (@SearchParams) {
                next TEXT if ( !defined $Text || $Text eq '' );

                # Check search attribute, we do not need to search for '*'.
                next TEXT if $Text =~ /^\*{1,3}$/;

                my $ValidateSuccess = $DynamicFielDBackendObject->ValueValidate(
                    DynamicFieldConfig => $DynamicField,
                    Value              => $Text,
                    UserID             => $Param{UserID} || 1,
                );
                if ( !$ValidateSuccess ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "Search not executed due to invalid value '"
                            . $Text
                            . "' on field '"
                            . $DynamicField->{Name} . "'!",
                    );
                    return;
                }

                push @TextToApply, $Text;
            }

            if ( scalar @TextToApply ) {
                my $Success = $EngineQueryHelperObj->QueryUpdate(
                    QueryParams => {
                        $DynamicFieldFullName => {
                            Operator => $DynamicFieldOperatorMap{$Operator},
                            Value    => \@TextToApply,
                        }
                    },
                    Strict => 1,
                );
            }
        }
    }

    # Special parameter for CustomerIDs from a customer company search result.
    if ( IsArrayRefWithData( $Param{CustomerCompanySearchCustomerIDs} ) ) {

        my $Success = $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $Self->{CustomerID} => $Param{CustomerCompanySearchCustomerIDs}
            },
            Strict => 1,
        );
    }

    # Special parameter to exclude some user logins from the search result.
    if ( IsArrayRefWithData( $Param{ExcludeUserLogins} ) ) {

        my $Success = $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $Self->{CustomerKey} => {
                    Operator => '!=',
                    Value    => $Param{ExcludeUserLogins},
                }
            },
            Strict => 1,
        );
    }

    # Add the valid option if needed.
    if ( $Self->{CustomerUserMap}->{CustomerValid} && $Valid ) {
        my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
        my $Success     = $EngineQueryHelperObj->QueryUpdate(
            QueryParams => {
                $InvertedFields->{ $Self->{CustomerUserMap}->{CustomerValid} }->{FieldName} => {
                    Operator => '=',
                    Value    => $ValidObject->ValidIDsGet(),
                }
            },
            Strict => 1,
        );
    }

    # Check if OrderBy contains only unique valid values.
    my %OrderBySeen;
    for my $OrderBy ( @{ $Param{OrderBy} } ) {

        if ( !$OrderBy || $OrderBySeen{$OrderBy} ) {

            $LogObject->Log(
                Priority => 'error',
                Message  => "OrderBy contains invalid value '$OrderBy' or the value is used more than once!",
            );
            return;
        }

        # Remember the value to check if it appears more than once.
        $OrderBySeen{$OrderBy} = 1;
    }

    # Check if OrderByDirection array contains only 'Up' or 'Down'.
    DIRECTION:
    for my $Direction ( @{ $Param{OrderByDirection} } ) {

        # Only 'Up' or 'Down' allowed.
        next DIRECTION if $Direction eq 'Up';
        next DIRECTION if $Direction eq 'Down';

        $LogObject->Log(
            Priority => 'error',
            Message  => "OrderByDirection can only contain 'Up' or 'Down'!",
        );
        return;
    }

    if ( $Result eq 'COUNT' ) {
        $EngineQueryHelperObj->{Query}->{Path} = "$IndexRealName/_count";
    }

    # The Order by clause is not needed for the result type 'COUNT'.
    if ( $Result ne 'COUNT' ) {

        my $Count = 0;

        $EngineQueryHelperObj->QueryApplyLimit(
            Limit  => $Param{Limit},
            Strict => 1,
        );

        ORDERBY:
        for my $OrderBy ( @{ $Param{OrderBy} } ) {

            my $Direction = 'Down';

            if ( $Param{OrderByDirection}->[$Count] ) {
                $Direction = $Param{OrderByDirection}->[$Count];
            }

            $Count++;

            next ORDERBY if !$OrderByTable{$OrderBy};

            $EngineQueryHelperObj->QueryApplySortBy(
                SortBy     => $OrderBy,
                OrderBy    => $Direction,
                ResultType => $Result,
                Strict     => 1,
            );

            next ORDERBY if $OrderBy eq 'UserLogin';
            push @{ $EngineQueryHelperObj->{Query}->{Body}->{fields} },
                $SearchCustomerUserObject->{Fields}->{$OrderBy}->{ColumnName};
        }

        # If there is a possibility that the ordering is not determined
        #   we add an descending ordering by id.
        if ( !grep { $_ eq 'UserLogin' } ( @{ $Param{OrderBy} } ) ) {

            $EngineQueryHelperObj->QueryApplySortBy(
                SortBy     => $InvertedFields->{ $Self->{CustomerKey} }->{FieldName},
                OrderBy    => 'Down',
                ResultType => $Result,
                Strict     => 1,
            );
        }
    }

    # Check if a cache exists before we ask the database.
    if ( $Self->{CacheObject} ) {

        my $JSONQuery = $JSONObject->Encode(
            Data => $EngineQueryHelperObj->{Query},
        );

        my $CacheData = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType} . '_CustomerSearchDetail::Elasticsearch',
            Key  => $JSONQuery,
        );

        if ( defined $CacheData ) {
            if ( ref $CacheData eq 'ARRAY' ) {
                return $CacheData;
            }
            elsif ( ref $CacheData eq '' ) {
                return $CacheData;
            }
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Invalid ref ' . ref($CacheData) . '!'
            );
            return;
        }
    }

    # return to fallback on any query build error
    return $Self->SUPER::CustomerSearchDetail(%Param) if !$EngineQueryHelperObj->QueryValidate();

    my $JSONQuery = $JSONObject->Encode(
        Data => $EngineQueryHelperObj->{Query},
    );

    my $Response = $EngineQueryHelperObj->QueryExecute();

    my $ResponseResult = $SearchObject->SearchFormat(
        Result     => $Response,
        ResultType => 'ARRAY_SIMPLE',
        IndexName  => 'CustomerUser',
        QueryData  => {
            Query => $EngineQueryHelperObj->{Query},
        },
        Fields => {
            $Self->{CustomerKey} => $InvertedFields->{ $Self->{CustomerKey} },
        },
    );

    my @CustomerUserData = @{ $ResponseResult->{CustomerUser} };

    # Handle the diffrent result types.
    if ( $Result eq 'COUNT' ) {

        if ( $Self->{CacheObject} ) {
            $Self->{CacheObject}->Set(
                Type  => $Self->{CacheType} . '_CustomerSearchDetail::Elasticsearch',
                Key   => $JSONQuery,
                Value => $CustomerUserData[0],
                TTL   => $Self->{CustomerUserMap}->{CacheTTL},
            );
        }

        return $CustomerUserData[0];
    }

    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType} . '_CustomerSearchDetail::Elasticsearch',
            Key   => $JSONQuery,
            Value => \@CustomerUserData,
            TTL   => $Self->{CustomerUserMap}->{CacheTTL},
        );
    }

    return \@CustomerUserData;
}

sub CustomerUserDataGet {
    my ( $Self, %Param ) = @_;

    my $SearchObject             = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::CustomerUser');

    # use db search by default as whole system can't use this function
    # due to performance issues (best to use it for low amount of requests at once)
    return $Self->SUPER::CustomerUserDataGet(%Param)
        if $SearchObject->{Fallback}
        || !$Param{UseAdvancedSearchEngine}
        || !$SearchCustomerUserObject->{ActiveDBBackend}->{ValidBackend};

    my $LogObject                     = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchQueryCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::CustomerUser');

    # check needed stuff
    if ( !$Param{User} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need User!',
        );
        return;
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Data = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "CustomerUserDataGet::$Param{User}::Elasticsearch",
        );
        return %{$Data} if ref $Data eq 'HASH';
    }

    my $InvertedFields = $SearchCustomerUserObject->FieldsInvertedFormat();
    my $IndexRealName  = $SearchCustomerUserObject->{Config}->{IndexRealName};

    my @FieldsMapWithoutDynamicFields   = grep { $_->[5] ne 'dynamic_field' } @{ $Self->{CustomerUserMap}->{Map} };
    my @FieldsNamesWithoutDynamicFields = map  { $_->[0] } @FieldsMapWithoutDynamicFields;
    my @AdditionalFields = $Self->{ForeignDB} ? () : qw(CreateTime CreateBy ChangeTime ChangeBy);
    my @FieldsToRetrieve = ( @FieldsNamesWithoutDynamicFields, @AdditionalFields );

    # use query builder
    my $EngineQueryHelperObj = $SearchQueryCustomerUserObject->EngineQueryHelperObjCreate(
        IndexName => 'CustomerUser',
        Query     => {
            Method => 'GET',
            Path   => "$IndexRealName/_search",
            Body   => {
                _source => \@FieldsToRetrieve,
                query   => {
                    term => {
                        $Self->{CustomerKey} . '_keyword' => $Param{User},
                    },
                },
                size => 1,
            },
        },
    );

    my $Response = $EngineQueryHelperObj->QueryExecute();

    my %FieldsToGetDef;
    for my $Field (@FieldsToRetrieve) {
        $FieldsToGetDef{$Field} = $SearchCustomerUserObject->{$Field};
    }

    my $Result = $SearchObject->SearchFormat(
        Result     => $Response,
        ResultType => 'ARRAY',
        IndexName  => 'CustomerUser',
        QueryData  => {
            Query => $EngineQueryHelperObj->{Query},
        },
        Fields => \%FieldsToGetDef,
    );

    my $CustomerUserData = $Result->{CustomerUser}->[0];

    # check data
    if ( !$CustomerUserData->{UserLogin} ) {

        # cache request
        if ( $Self->{CacheObject} ) {
            $Self->{CacheObject}->Set(
                Type  => $Self->{CacheType},
                Key   => "CustomerUserDataGet::$Param{User}::Elasticsearch",
                Value => {},
                TTL   => $Self->{CustomerUserMap}->{CacheTTL},
            );
        }
        return;
    }

    my $CustomerUserListFieldsMap = $Self->{CustomerUserMap}->{CustomerUserListFields};
    if ( !IsArrayRefWithData($CustomerUserListFieldsMap) ) {
        $CustomerUserListFieldsMap = [ 'first_name', 'last_name', 'email', ];
    }

    # Order fields by CustomerUserListFields (see bug#13821).
    my @CustomerUserListFields;
    for my $Field ( @{$CustomerUserListFieldsMap} ) {
        my @FieldNames = map { $_->[0] } grep { $_->[2] eq $Field } @{ $Self->{CustomerUserMap}->{Map} };
        push @CustomerUserListFields, $FieldNames[0];
    }

    my $UserMailString = '';
    my @UserMailStringParts;

    FIELD:
    for my $Field (@CustomerUserListFields) {
        next FIELD if !$CustomerUserData->{$Field};

        push @UserMailStringParts, $CustomerUserData->{$Field};
    }
    $UserMailString = join ' ', @UserMailStringParts;
    $UserMailString =~ s/^(.*)\s(.+?\@.+?\..+?)(\s|)$/"$1" <$2>/;

    # add the UserMailString to the data hash
    $CustomerUserData->{UserMailString} = $UserMailString;

    # compat!
    $CustomerUserData->{UserID} = $CustomerUserData->{UserLogin};

    # get preferences
    my %Preferences = $Self->GetPreferences( UserID => $CustomerUserData->{UserID} );

    # add last login timestamp
    if ( $Preferences{UserLastLogin} ) {

        my $DateTimeObject = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => {
                Epoch => $Preferences{UserLastLogin},
            },
        );

        $Preferences{UserLastLoginTimestamp} = $DateTimeObject->ToString();

    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "CustomerUserDataGet::$Param{User}::Elasticsearch",
            Value => { %{$CustomerUserData}, %Preferences },
            TTL   => $Self->{CustomerUserMap}->{CacheTTL},
        );
    }

    return ( %{$CustomerUserData}, %Preferences );
}

1;

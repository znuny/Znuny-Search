# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::FAQ;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::FAQ',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Search::Object::Default::Article',
    'Kernel::System::Group',
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Query::FAQ - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchQueryFAQObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::FAQ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::FAQ');

    for my $Property (
        qw(Fields SupportedOperators OperatorMapping DefaultSearchLimit
        SupportedResultTypes Config ExternalFields SearchableFields AttachmentFields )
        )
    {
        $Self->{ 'Index' . $Property } = $IndexObject->{$Property};
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{ActiveEngine} = $SearchObject->{Config}->{ActiveEngine} // '';

    if ( !$SearchObject->{Fallback} ) {
        $MainObject->Require(
            "Kernel::System::Search::Object::EngineQueryHelper::$Self->{ActiveEngine}",
        );
    }

    bless( $Self, $Type );

    return $Self;
}

=head2 LookupFAQFieldsGet()

return lookup fields for FAQ

    my $LookupFAQFields = $SearchQueryFAQObject->LookupFAQFieldsGet();

=cut

sub LookupFAQFieldsGet {
    my ( $Self, %Param ) = @_;

    #TODO
    #     my $LookupFields = {
    #         Queue => {
    #             Module           => "Kernel::System::Queue",
    #             FunctionName     => 'QueueLookup',
    #             FunctionNameList => 'GetAllQueues',
    #             ParamName        => 'Queue'
    #         },
    #         SLA => {
    #             Module           => "Kernel::System::SLA",
    #             FunctionName     => "SLALookup",
    #             FunctionNameList => 'SLAList',
    #             ParamName        => "Name"
    #         },
    #         Lock => {
    #             Module           => "Kernel::System::Lock",
    #             FunctionName     => "LockLookup",
    #             FunctionNameList => 'LockList',
    #             ParamName        => "Lock"
    #         },
    #         Type => {
    #             Module           => "Kernel::System::Type",
    #             FunctionName     => "TypeLookup",
    #             FunctionNameList => 'TypeList',
    #             ParamName        => "Type"
    #         },
    #         Service => {
    #             Module           => "Kernel::System::Service",
    #             FunctionName     => "ServiceLookup",
    #             FunctionNameList => 'ServiceList',
    #             ParamName        => "Name"
    #         },
    #         Owner => {
    #             Module           => "Kernel::System::User",
    #             FunctionName     => "UserLookup",
    #             FunctionNameList => 'UserList',
    #             ParamName        => "UserLogin"
    #         },
    #         Responsible => {
    #             Module           => "Kernel::System::User",
    #             FunctionName     => "UserLookup",
    #             FunctionNameList => 'UserList',
    #             ParamName        => "UserLogin"
    #         },
    #         Priority => {
    #             Module           => "Kernel::System::Priority",
    #             FunctionName     => "PriorityLookup",
    #             FunctionNameList => 'PriorityList',
    #             ParamName        => "Priority"
    #         },
    #         State => {
    #             Module           => "Kernel::System::State",
    #             FunctionName     => "StateLookup",
    #             FunctionNameList => 'StateList',
    #             ParamName        => "State"
    #         },
    #         Customer => {
    #             Module           => "Kernel::System::CustomerCompany",
    #             FunctionName     => "CustomerCompanyList",
    #             FunctionNameList => 'CustomerCompanyList',
    #             ParamName        => "Search"
    #         },
    #         ChangeByLogin => {
    #             Module           => "Kernel::System::User",
    #             FunctionName     => "UserLookup",
    #             FunctionNameList => 'UserList',
    #             ParamName        => "UserLogin",
    #             AttributeName    => "ChangeBy"
    #         },
    #         CreateByLogin => {
    #             Module           => "Kernel::System::User",
    #             FunctionName     => "UserLookup",
    #             FunctionNameList => 'UserList',
    #             ParamName        => "UserLogin",
    #             AttributeName    => "CreateBy"
    #         }
    #     };

    #     return $LookupFields;
}

=head2 LookupFAQFields()

search & delete lookup fields in standard query params, then perform lookup
of deleted fields and return it

    my $LookupQueryParams = $SearchQueryFAQObject->LookupFAQFields(
        QueryParams     => $QueryParams,
    );

=cut

sub LookupFAQFields {
    my ( $Self, %Param ) = @_;

    #TODO
    #     my $LookupFields = $Self->LookupFAQFieldsGet();

    #     my $LookupQueryParams;

    #     if ( $Param{QueryParams}->{Customer} ) {
    #         my $Key   = 'Customer';
    #         my $Param = $Param{QueryParams}->{$Key};

    #         if ( defined $Param ) {
    #             my $LookupField = $LookupFields->{$Key};
    #             my $Module      = $Kernel::OM->Get( $LookupField->{Module} );
    #             my $ParamName   = $LookupField->{ParamName};

    #             my $FunctionName = $LookupField->{FunctionName};

    #             my @IDs;
    #             my @Param = IsString( delete $Param{QueryParams}->{Customer} )
    #                 ?
    #                 ($Param)
    #                 : @{$Param};
    #             VALUE:
    #             for my $Value (@Param) {
    #                 my %CustomerCompanyList = $Module->$FunctionName(
    #                     "$ParamName" => $Value
    #                 );

    #                 my $CustomerID;
    #                 CUSTOMER_COMPANY:
    #                 for my $CustomerCompanyID ( sort keys %CustomerCompanyList ) {
    #                     my %CustomerCompany = $Module->CustomerCompanyGet(
    #                         CustomerID => $CustomerCompanyID,
    #                     );

 #                     if ( $CustomerCompany{CustomerCompanyName} && $CustomerCompany{CustomerCompanyName} eq $Value ) {
 #                         $CustomerID = $CustomerCompanyID;
 #                     }
 #                 }

    #                 delete $Param{QueryParams}->{$Key};
    #                 next VALUE if !$CustomerID;
    #                 push @IDs, $CustomerID;
    #             }

    #             if ( !@IDs ) {
    #                 return {
    #                     Error => 'LookupValuesNotFound'
    #                 };
    #             }

    #             my $LookupQueryParam = {
    #                 Operator   => "=",
    #                 Value      => \@IDs,
    #                 ReturnType => 'SCALAR',
    #                 Type       => 'String',
    #             };

    #             $LookupQueryParams->{ $Key . 'ID' } = $LookupQueryParam;
    #         }
    #         else {
    #             delete $Param{QueryParams}->{$Key};
    #         }
    #     }

    #     if ( $Param{QueryParams}->{CustomerUser} ) {
    #         my $Param = $Param{QueryParams}->{CustomerUser};

    #         if ( defined $Param ) {
    #             my @Param = IsString( delete $Param{QueryParams}->{CustomerUser} )
    #                 ?
    #                 ($Param)
    #                 : @{$Param};
    #             my $LookupQueryParam = {
    #                 Operator   => "=",
    #                 Value      => \@Param,
    #                 ReturnType => 'SCALAR',
    #                 Type       => 'String',
    #             };

    #             $LookupQueryParams->{CustomerUserID} = $LookupQueryParam;
    #         }
    #         else {
    #             delete $Param{QueryParams}->{CustomerUser};
    #         }
    #     }

    #     # get lookup fields that exists in "QueryParams" parameter
    #     my %UsedLookupFields = map { $_ => $LookupFields->{$_} }
    #         grep { $LookupFields->{$_} }
    #         keys %{ $Param{QueryParams} };

    #     LOOKUPFIELD:
    #     for my $Key ( sort keys %UsedLookupFields ) {

    #         my $Param = $Param{QueryParams}->{$Key};
    #         if ( !defined $Param ) {
    #             delete $Param{QueryParams}->{$Key};
    #             next LOOKUPFIELD;
    #         }

    #         # lookup every field for ID
    #         my $LookupField   = $LookupFields->{$Key};
    #         my $Module        = $Kernel::OM->Get( $LookupField->{Module} );
    #         my $FunctionName  = $LookupField->{FunctionName};
    #         my $ParamName     = $LookupField->{ParamName};
    #         my $AttributeName = $LookupField->{AttributeName} || $Key . 'ID';
    #         my @IDs;
    #         my @Param = IsString($Param)
    #             ?
    #             ($Param)
    #             : @{$Param};

    #         VALUE:
    #         for my $Value (@Param) {

    #             my $FieldID = $Module->$FunctionName(
    #                 "$ParamName" => $Value
    #             );

    #             delete $Param{QueryParams}->{$Key};
    #             next VALUE if !$FieldID;
    #             push @IDs, $FieldID;
    #         }

    #         if ( !@IDs ) {
    #             return {
    #                 Error => 'LookupValuesNotFound'
    #             };
    #         }

    #         my $LookupQueryParam = {
    #             Operator   => "=",
    #             Value      => \@IDs,
    #             ReturnType => 'SCALAR',
    #             Type       => 'Integer',
    #         };

    #         $LookupQueryParams->{$AttributeName} = $LookupQueryParam;
    #     }

    #     if ( $Param{QueryParams}->{StateType} ) {

    #         my $StateObject = $Kernel::OM->Get('Kernel::System::State');
    #         my $Param       = $Param{QueryParams}->{StateType};
    #         if ( defined $Param ) {
    #             my @Param = IsString( delete $Param{QueryParams}->{StateType} )
    #                 ?
    #                 ($Param)
    #                 : @{$Param};

    #             my @StateIDList = $StateObject->StateGetStatesByType(
    #                 StateType => \@Param,
    #                 Result    => 'ID',
    #             );

    #             if ( !@StateIDList ) {
    #                 return {
    #                     Error => 'LookupValuesNotFound',
    #                 };
    #             }

    #             my $LookupQueryParam = {
    #                 Operator   => "=",
    #                 Value      => \@StateIDList,
    #                 ReturnType => 'SCALAR',
    #                 Type       => 'String',
    #             };

    #             # "State" filter is present, check if states found by "StateType" parameter
    #             # are in states from "State" filter - those are matched together by "AND"
    #             if ( $LookupQueryParams->{StateID} && IsArrayRefWithData( $LookupQueryParams->{StateID}->{Value} ) ) {
    #                 my @NewStateIDFilter;

    #                 for my $AlreadyAddedStateID ( @{ $LookupQueryParams->{StateID}->{Value} } ) {
    #                     my @FoundInStateTypeFilter = grep { $_ eq $AlreadyAddedStateID } @StateIDList;

    #                     if ( $FoundInStateTypeFilter[0] ) {
    #                         push @NewStateIDFilter, $FoundInStateTypeFilter[0];
    #                     }
    #                 }

    #                 # state from "StateID" query param was found, but afterwards
    #                 # those states did not match any state types from "StateType" param
    #                 if ( !@NewStateIDFilter ) {
    #                     return {
    #                         Error => 'StateTypesFilteredEmptyResponse',
    #                     };
    #                 }
    #             }
    #             else {
    #                 $LookupQueryParams->{StateID} = $LookupQueryParam;
    #             }
    #         }
    #         else {
    #             delete $Param{QueryParams}->{StateType};
    #         }
    #     }

    #     return $LookupQueryParams;
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryFAQObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
    );

=cut

sub _QueryParamsPrepare {
    my ( $Self, %Param ) = @_;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my %QueryParams;

    if ( IsHashRefWithData( $Param{QueryParams} ) ) {
        %QueryParams = %{ $Param{QueryParams} };
    }

    # support lookup fields
    my $LookupQueryParams = $Self->LookupFAQFields(
        QueryParams => \%QueryParams,
    ) // {};

    # on lookup error there should be no response
    # so create the query param that will always
    # return no data
    # error does not need to be critical
    # it can be simply no name ids found for one of the
    # query parameter
    # so response would always be empty
    if ( delete $LookupQueryParams->{Error} ) {
        %QueryParams = (
            ID => -1,
        );
    }

    # support permissions
    if ( $QueryParams{UserID} ) {

        # get users groups
        my %GroupList = $GroupObject->PermissionUserGet(
            UserID => delete $QueryParams{UserID},
            Type   => delete $QueryParams{Permissions} || 'ro',
        );

        push @{ $QueryParams{GroupID} }, keys %GroupList;
    }

    # additional check if valid groups was specified
    # based on UserID and GroupID params
    # if no, treat it as there is no permissions
    # empty response will be retrieved
    if ( !$Param{NoPermissions} && !IsArrayRefWithData( $QueryParams{GroupID} ) ) {
        $QueryParams{GroupID} = [-1];
    }

    my $SearchParams = $Self->SUPER::_QueryParamsPrepare(
        %Param,
        QueryParams => \%QueryParams,
    ) // {};

    if ( ref $SearchParams eq 'HASH' && $SearchParams->{Error} ) {
        return $SearchParams;
    }

    # merge looked-up fields with standard fields
    for my $LookupParam ( sort keys %{$LookupQueryParams} ) {
        push @{ $SearchParams->{$LookupParam}->{Query} }, $LookupQueryParams->{$LookupParam};
    }

    return $SearchParams;
}

=head2 _QueryFieldCheck()

check specified field for index

    my $Result = $SearchQueryFAQObject->_QueryFieldCheck(
        Name => 'SLAID',
        Value => '1', # by default value is passed but is not used
                      # in standard query module
    );

=cut

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return 1 if $Param{Name} eq "GroupID";
    if ( $Param{Name} =~ m{\A(Attachment_.+)} && !$Self->{IndexConfig}->{Settings}->{IndexAttachments} ) {
        return;
    }

    return 1 if $Param{Name} =~ m{\A(DynamicField_.+)};

    if ( $Param{Name} =~ m{\AAttachment_(.+)} ) {
        if ( !$Param{NoMappingCheck} ) {
            return 1 if $Self->{IndexAttachmentFields}->{$1};
        }
    }

    return $Self->SUPER::_QueryFieldCheck(%Param);
}

=head2 _QueryFieldDataSet()

set data for field

    my $Result = $SearchQueryFAQObject->_QueryFieldDataSet(
        Name => 'SLAID',
    );

=cut

sub _QueryFieldDataSet {
    my ( $Self, %Param ) = @_;

    my $DefaultValue = {
        ReturnType => 'SCALAR',
    };
    my $Data = $DefaultValue;

    if ( $Param{Name} eq '_id' ) {
        $Data->{Type} = 'String';
        return $DefaultValue;
    }

    if ( $Self->{IndexFields}->{ $Param{Name} } ) {
        for my $Property (qw(Type ReturnType)) {
            if ( $Self->{IndexFields}->{ $Param{Name} }->{$Property} ) {
                $Data->{$Property} = $Self->{IndexFields}->{ $Param{Name} }->{$Property};
            }
        }
    }
    elsif ( $Self->{IndexExternalFields}->{ $Param{Name} } ) {
        for my $Property (qw(Type ReturnType)) {
            if ( $Self->{IndexExternalFields}->{ $Param{Name} }->{$Property} ) {
                $Data->{$Property} = $Self->{IndexExternalFields}->{ $Param{Name} }->{$Property};
            }
        }
    }

    # get information about query param if field
    # matches specified regexp
    elsif ( $Param{Name} =~ m{\A(?:DynamicField_(.+))} ) {
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        my $DynamicFieldName = $1 || $2;

        # get single dynamic field config
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $DynamicFieldName,
        );

        # get object - "FAQ"
        my $ObjectType = $DynamicFieldConfig->{ObjectType};

        if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
            my $Info = $Self->_QueryDynamicFieldInfoGet(
                ObjectType         => $ObjectType,
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            $Data = $Info;
        }

        # dynamic field probably does not exists
        # determine if query is prepared for engine
        # if yes, then there is no need to get it validated
        # as at this time Znuny does not contain this dynamic field
        # but advanced engine have it saved
        elsif ( $Param{QueryFor} && $Param{QueryFor} eq 'Engine' ) {

            # apply the least restricted data
            return {
                ColumnName => 'DynamicField' . $DynamicFieldName,
                Name       => $DynamicFieldName,
                ReturnType => 'SCALAR',
                Type       => 'String',
            };
        }
    }
    elsif ( $Param{Name} =~ m{\AAttachment_(.+)\z} ) {

        my $AttachmentParam = $1;
        if ($AttachmentParam) {
            if ( $Self->{IndexAttachmentFields}->{$AttachmentParam} ) {
                for my $Property (qw(Type ReturnType)) {
                    if (
                        $Self->{IndexAttachmentFields}->{$AttachmentParam}->{$Property}
                        )
                    {
                        $Data->{$Property} = $Self->{IndexAttachmentFields}->{$AttachmentParam}
                            ->{$Property};
                    }
                }
            }
        }
    }

    return $Data;
}

1;

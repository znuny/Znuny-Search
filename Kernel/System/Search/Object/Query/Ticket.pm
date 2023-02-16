# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::Ticket',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Search::Object::Default::Article',
    'Kernel::System::Search::Object::Default::ArticleDataMIME',
    'Kernel::System::Group',
);

=head1 NAME

Kernel::System::Search::Object::Query::Ticket - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchQueryTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');

    for my $Property (
        qw(Fields SupportedOperators OperatorMapping DefaultSearchLimit
        SupportedResultTypes Config ExternalFields SearchableFields )
        )
    {
        $Self->{ 'Index' . $Property } = $IndexObject->{$Property};
    }

    bless( $Self, $Type );

    return $Self;
}

=head2 LookupTicketFieldsGet()

return lookup fields for Ticket

    my $LookupTicketFields = $SearchQueryTicketObject->LookupTicketFieldsGet();

=cut

sub LookupTicketFieldsGet {
    my ( $Self, %Param ) = @_;

    my $LookupFields = {
        Queue => {
            Module           => "Kernel::System::Queue",
            FunctionName     => 'QueueLookup',
            FunctionNameList => 'GetAllQueues',
            ParamName        => 'Queue'
        },
        SLA => {
            Module           => "Kernel::System::SLA",
            FunctionName     => "SLALookup",
            FunctionNameList => 'SLAList',
            ParamName        => "Name"
        },
        Lock => {
            Module           => "Kernel::System::Lock",
            FunctionName     => "LockLookup",
            FunctionNameList => 'LockList',
            ParamName        => "Lock"
        },
        Type => {
            Module           => "Kernel::System::Type",
            FunctionName     => "TypeLookup",
            FunctionNameList => 'TypeList',
            ParamName        => "Type"
        },
        Service => {
            Module           => "Kernel::System::Service",
            FunctionName     => "ServiceLookup",
            FunctionNameList => 'ServiceList',
            ParamName        => "Name"
        },
        Owner => {
            Module           => "Kernel::System::User",
            FunctionName     => "UserLookup",
            FunctionNameList => 'UserList',
            ParamName        => "UserLogin"
        },
        Responsible => {
            Module           => "Kernel::System::User",
            FunctionName     => "UserLookup",
            FunctionNameList => 'UserList',
            ParamName        => "UserLogin"
        },
        Priority => {
            Module           => "Kernel::System::Priority",
            FunctionName     => "PriorityLookup",
            FunctionNameList => 'PriorityList',
            ParamName        => "Priority"
        },
        State => {
            Module           => "Kernel::System::State",
            FunctionName     => "StateLookup",
            FunctionNameList => 'StateList',
            ParamName        => "State"
        },
        Customer => {
            Module           => "Kernel::System::CustomerCompany",
            FunctionName     => "CustomerCompanyList",
            FunctionNameList => 'CustomerCompanyList',
            ParamName        => "Search"
        },
        ChangeByLogin => {
            Module           => "Kernel::System::User",
            FunctionName     => "UserLookup",
            FunctionNameList => 'UserList',
            ParamName        => "UserLogin",
            AttributeName    => "ChangeBy"
        },
        CreateByLogin => {
            Module           => "Kernel::System::User",
            FunctionName     => "UserLookup",
            FunctionNameList => 'UserList',
            ParamName        => "UserLogin",
            AttributeName    => "CreateBy"
        }
    };

    return $LookupFields;
}

=head2 LookupTicketFields()

search & delete lookup fields in standard query params, then perform lookup
of deleted fields and return it

    my $LookupQueryParams = $SearchQueryTicketObject->LookupTicketFields(
        QueryParams     => $QueryParams,
    );

=cut

sub LookupTicketFields {
    my ( $Self, %Param ) = @_;

    my $LookupFields = $Self->LookupTicketFieldsGet();

    my $LookupQueryParams;

    if ( $Param{QueryParams}->{Customer} ) {
        my $Key = 'Customer';

        my $LookupField = $LookupFields->{$Key};
        my $Module      = $Kernel::OM->Get( $LookupField->{Module} );
        my $ParamName   = $LookupField->{ParamName};

        my $FunctionName = $LookupField->{FunctionName};
        my $Param        = $Param{QueryParams}->{Customer};

        my @IDs;
        my @Param = IsString( delete $Param{QueryParams}->{Customer} )
            ?
            ($Param)
            : @{$Param};
        VALUE:
        for my $Value (@Param) {
            my %CustomerCompanyList = $Module->$FunctionName(
                "$ParamName" => $Value
            );

            my $CustomerID;
            CUSTOMER_COMPANY:
            for my $CustomerCompanyID ( sort keys %CustomerCompanyList ) {
                my %CustomerCompany = $Module->CustomerCompanyGet(
                    CustomerID => $CustomerCompanyID,
                );

                if ( $CustomerCompany{CustomerCompanyName} && $CustomerCompany{CustomerCompanyName} eq $Value ) {
                    $CustomerID = $CustomerCompanyID;
                }
            }

            delete $Param{QueryParams}->{$Key};
            next VALUE if !$CustomerID;
            push @IDs, $CustomerID;
        }

        if ( !scalar @IDs ) {
            return {
                Error => 'LookupValuesNotFound'
            };
        }

        my $LookupQueryParam = {
            Operator   => "=",
            Value      => \@IDs,
            ReturnType => 'SCALAR',
        };

        $LookupQueryParams->{ $Key . 'ID' } = $LookupQueryParam;
    }

    if ( $Param{QueryParams}->{CustomerUser} ) {
        my $Param = $Param{QueryParams}->{CustomerUser};
        my @Param = IsString( delete $Param{QueryParams}->{CustomerUser} )
            ?
            ($Param)
            : @{$Param};
        my $LookupQueryParam = {
            Operator   => "=",
            Value      => \@Param,
            ReturnType => 'SCALAR',
        };

        $LookupQueryParams->{CustomerUserID} = $LookupQueryParam;
    }

    # get lookup fields that exists in "QueryParams" parameter
    my %UsedLookupFields = map { $_ => $LookupFields->{$_} }
        grep { $LookupFields->{$_} }
        keys %{ $Param{QueryParams} };

    LOOKUPFIELD:
    for my $Key ( sort keys %UsedLookupFields ) {

        # lookup every field for ID
        my $LookupField   = $LookupFields->{$Key};
        my $Module        = $Kernel::OM->Get( $LookupField->{Module} );
        my $Param         = $Param{QueryParams}->{$Key};
        my $FunctionName  = $LookupField->{FunctionName};
        my $ParamName     = $LookupField->{ParamName};
        my $AttributeName = $LookupField->{AttributeName} || $Key . 'ID';

        my @IDs;
        my @Param = IsString($Param)
            ?
            ($Param)
            : @{$Param};
        VALUE:
        for my $Value (@Param) {

            my $FieldID = $Module->$FunctionName(
                "$ParamName" => $Value
            );

            delete $Param{QueryParams}->{$Key};
            next VALUE if !$FieldID;
            push @IDs, $FieldID;
        }

        if ( !scalar @IDs ) {
            return {
                Error => 'LookupValuesNotFound'
            };
        }

        my $LookupQueryParam = {
            Operator   => "=",
            Value      => \@IDs,
            ReturnType => 'SCALAR',
        };

        $LookupQueryParams->{$AttributeName} = $LookupQueryParam;
    }

    return $LookupQueryParams;
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryTicketObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
    );

=cut

sub _QueryParamsPrepare {
    my ( $Self, %Param ) = @_;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my $QueryParams = $Param{QueryParams};

    # support lookup fields
    my $LookupQueryParams = $Self->LookupTicketFields(
        QueryParams => $QueryParams,
    ) // {};

    # on lookup error there should be no response
    # so create the query param that will always
    # return no data
    # error does not need to be critical
    # it can be simply no name ids found for one of the
    # query parameter
    # so response would always be empty
    if ( delete $LookupQueryParams->{Error} ) {
        $QueryParams = {
            TicketID => -1,
        };
    }

    # support permissions
    if ( $QueryParams->{UserID} ) {

        # get users groups
        my %GroupList = $GroupObject->PermissionUserGet(
            UserID => delete $QueryParams->{UserID},
            Type   => delete $QueryParams->{Permissions} || 'ro',
        );

        push @{ $QueryParams->{GroupID} }, keys %GroupList;
    }

    # additional check if valid groups was specified
    # based on UserID and GroupID params
    # if no, treat it as there is no permissions
    # empty response will be retrieved
    if ( !$Param{NoPermissions} && !IsArrayRefWithData( $QueryParams->{GroupID} ) ) {
        $QueryParams->{GroupID} = [-1];
    }

    my $SearchParams = $Self->SUPER::_QueryParamsPrepare(
        %Param,
        QueryParams => $QueryParams,
    ) // {};

    if ( ref $SearchParams eq 'HASH' && $SearchParams->{Error} ) {
        return $SearchParams;
    }

    # merge lookupped fields with standard fields
    for my $LookupParam ( sort keys %{$LookupQueryParams} ) {
        push @{ $SearchParams->{$LookupParam}->{Query} }, $LookupQueryParams->{$LookupParam};
    }

    return $SearchParams;
}

=head2 _QueryFieldCheck()

check specified field for index

    my $Result = $SearchQueryTicketObject->_QueryFieldCheck(
        Name => 'SLAID',
        Value => '1', # by default value is passed but is not used
                      # in standard query module
    );

=cut

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return 1 if $Param{Name} eq "GroupID";
    return 1 if $Param{Name} =~ m{\A(DynamicField_.+)|(Article_DynamicField_.+)|(Attachment_.+)};

    if ( $Param{Name} =~ m{\AArticle_(.+)} ) {
        my $SearchArticleObject         = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
        my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIME');

        if ( !$Param{NoMappingCheck} ) {
            return 1 if $SearchArticleObject->{Fields}->{$1};
            return 1 if $SearchArticleDataMIMEObject->{Fields}->{$1};
        }
    }

    return $Self->SUPER::_QueryFieldCheck(%Param);
}

=head2 _QueryFieldDataSet()

set data for field

    my $Result = $SearchQueryTicketObject->_QueryFieldDataSet(
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
    elsif ( $Param{Name} =~ m{\A(?:DynamicField_(.+))|(?:Article_DynamicField_(.+))} ) {
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        my $DynamicFieldName = $1 || $2;

        # get single dynamic field config
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $DynamicFieldName,
        );

        # get object - "Ticket" or "Article"
        my $ObjectType = $DynamicFieldConfig->{ObjectType};

        if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
            my $Info = $Self->_QueryDynamicFieldInfoGet(
                ObjectType         => $ObjectType,
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            $Data = $Info;
        }
    }
    elsif ( $Param{Name} =~ m{\AArticle_(.+)\z} ) {

        my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
        my $ArticleFields       = $SearchArticleObject->DenormalizedArticleFieldsGet();

        my $ArticleParam = $1;
        if ($ArticleParam) {
            for my $FieldStructure (qw(Fields ExternalFields)) {
                if ( $ArticleFields->{$FieldStructure}->{$ArticleParam} ) {
                    for my $Property (qw(Type ReturnType)) {
                        if ( $ArticleFields->{$FieldStructure}->{$ArticleParam}->{$Property} ) {
                            $Data->{$Property} = $ArticleFields->{$FieldStructure}->{$ArticleParam}->{$Property};
                        }
                    }
                    return $Data;
                }
            }
        }
    }
    elsif ( $Param{Name} =~ m{\AAttachment_(.+)\z} ) {
        my $SearchArticleDataMIMEAttachmentObject
            = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment');

        my $AttachmentParam = $1;
        if ($AttachmentParam) {
            for my $FieldStructure (qw(Fields ExternalFields)) {
                if ( $SearchArticleDataMIMEAttachmentObject->{$FieldStructure}->{$AttachmentParam} ) {
                    for my $Property (qw(Type ReturnType)) {
                        if (
                            $SearchArticleDataMIMEAttachmentObject->{$FieldStructure}->{$AttachmentParam}->{$Property}
                            )
                        {
                            $Data->{$Property}
                                = $SearchArticleDataMIMEAttachmentObject->{$FieldStructure}->{$AttachmentParam}
                                ->{$Property};
                        }
                    }
                }
            }
        }
    }

    return $Data;
}

=head2 _QueryDynamicFieldInfoGet()

get info for dynamic field in query params

    my $Result = $SearchQueryTicketObject->_QueryDynamicFieldInfoGet(
        DynamicFieldConfig => $DynamicFieldConfig,
    );

=cut

sub _QueryDynamicFieldInfoGet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(DynamicFieldConfig)) {

        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $DynamicFieldConfig     = $Param{DynamicFieldConfig};
    my $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};

    # get return type for dynamic field
    my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        FieldType          => 'Edit',
    );

    # set type of field
    my $Type = 'String';

    if (
        $DynamicFieldConfig->{FieldType}
        && (
            $DynamicFieldConfig->{FieldType} eq 'Date'
            || $DynamicFieldConfig->{FieldType} eq 'DateTime'
        )
        )
    {
        $Type = 'Date';
    }

    # apply properties that are set in object fields mapping
    return {
        ColumnName => $DynamicFieldColumnName,
        Name       => $DynamicFieldConfig->{Name},
        ReturnType => $FieldValueType->{$DynamicFieldColumnName} || 'SCALAR',
        Type       => $Type,
    };
}

1;

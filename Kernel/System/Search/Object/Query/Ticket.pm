# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
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

    my $QueryTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');

    # get index specified fields
    $Self->{IndexFields}               = $IndexObject->{Fields};
    $Self->{IndexSupportedOperators}   = $IndexObject->{SupportedOperators};
    $Self->{IndexOperatorMapping}      = $IndexObject->{OperatorMapping};
    $Self->{IndexDefaultSearchLimit}   = $IndexObject->{DefaultSearchLimit};
    $Self->{IndexSupportedResultTypes} = $IndexObject->{SupportedResultTypes};
    $Self->{IndexConfig}               = $IndexObject->{Config};

    bless( $Self, $Type );

    return $Self;
}

=head2 LookupTicketFields()

search & delete lookup fields in standard query params, then perform lookup
of deleted fields and return it

    my $LookupQueryParams = $SearchQueryObject->LookupTicketFields(
        QueryParams     => $QueryParams,
    );

=cut

sub LookupTicketFields {
    my ( $Self, %Param ) = @_;

    my $LookupFields = {
        Queue => {
            Module       => "Kernel::System::Queue",
            FunctionName => 'QueueLookup',
            ParamName    => 'Queue'
        },
        SLA => {
            Module       => "Kernel::System::SLA",
            FunctionName => "SLALookup",
            ParamName    => "Name"
        },
        Lock => {
            Module       => "Kernel::System::Lock",
            FunctionName => "LockLookup",
            ParamName    => "Lock"
        },
        Type => {
            Module       => "Kernel::System::Type",
            FunctionName => "TypeLookup",
            ParamName    => "Type"
        },
        Service => {
            Module       => "Kernel::System::Service",
            FunctionName => "ServiceLookup",
            ParamName    => "Name"
        },
        Owner => {
            Module       => "Kernel::System::User",
            FunctionName => "UserLookup",
            ParamName    => "UserLogin"
        },
        Responsible => {
            Module       => "Kernel::System::User",
            FunctionName => "UserLookup",
            ParamName    => "UserLogin"
        },
        Priority => {
            Module       => "Kernel::System::Priority",
            FunctionName => "PriorityLookup",
            ParamName    => "Priority"
        },
        State => {
            Module       => "Kernel::System::State",
            FunctionName => "StateLookup",
            ParamName    => "State"
        }
    };

    # TO-DO support for customer users, create by,change by
    my $CustomerLookupField = {
        Customer => {
            Module       => "Kernel::System::CustomerCompany",
            FunctionName => "CustomerCompanyList",
            ParamName    => "Search"
        }
    };

    my $LookupQueryParams;

    if ( $Param{QueryParams}->{Customer} ) {
        my $Key = 'Customer';

        my $LookupField = $CustomerLookupField->{$Key};
        my $Module      = $Kernel::OM->Get( $LookupField->{Module} );

        my $FunctionName = $LookupField->{FunctionName};

        my @IDs;
        VALUE:
        for my $Value ( @{ $Param{QueryParams}->{$Key} } ) {
            my $ParamName = $LookupField->{ParamName};

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

    # get lookup fields that exists in "QueryParams" parameter
    my %UsedLookupFields = map { $_ => $LookupFields->{$_} }
        grep { $LookupFields->{$_} }
        keys %{ $Param{QueryParams} };

    LOOKUPFIELD:
    for my $Key ( sort keys %UsedLookupFields ) {

        # lookup every field for ID
        my $LookupField = $LookupFields->{$Key};
        my $Module      = $Kernel::OM->Get( $LookupField->{Module} );

        my @IDs;
        VALUE:
        for my $Value ( @{ $Param{QueryParams}->{$Key} } ) {
            my $ParamName = $LookupField->{ParamName};

            my $FunctionName = $LookupField->{FunctionName};
            my $FieldID      = $Module->$FunctionName(
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

        $LookupQueryParams->{ $Key . 'ID' } = $LookupQueryParam;
    }

    return $LookupQueryParams;
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
    );

=cut

sub _QueryParamsPrepare {
    my ( $Self, %Param ) = @_;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # support lookup fields
    my $LookupQueryParams = $Self->LookupTicketFields(
        QueryParams => $Param{QueryParams},
    ) // {};

    # on lookup error there should be no response
    # so create the query param that will always
    # return no data
    # error does not need to be critical
    # it can be simply no name ids found for one of the
    # query parameter
    # so response would always be empty
    if ( delete $LookupQueryParams->{Error} ) {
        $Param{QueryParams} = {
            TicketID => -1
        };
    }

    # support permissions
    if ( $Param{QueryParams}{UserID} ) {

        # get users groups
        my %GroupList = $GroupObject->PermissionUserGet(
            UserID => $Param{QueryParams}{UserID},
            Type   => $Param{QueryParams}{Permissions} || 'ro',
        );

        push @{ $Param{QueryParams}{GroupID} }, keys %GroupList;
    }

    # additional check if valid groups was specified
    # based on UserID and GroupID params
    # if no, treat it as there is no permissions
    # empty response will be retrieved
    if ( !IsArrayRefWithData( $Param{QueryParams}{GroupID} ) ) {
        $Param{QueryParams}{GroupID} = [-1];
    }

    my $SearchParams = $Self->SUPER::_QueryParamsPrepare(%Param) // {};

    # merge lookupped fields with standard fields
    for my $LookupParam ( sort keys %{$LookupQueryParams} ) {
        push @{ $SearchParams->{$LookupParam}->{Query} }, $LookupQueryParams->{$LookupParam};
    }

    return $SearchParams;
}

=head2 _QueryFieldCheck()

check specified field for index

    my $Result = $SearchQueryObject->_QueryFieldCheck(
        Name => 'SLAID',
        Value => '1', # by default value is passed but is not used
                      # in standard query module
    );

=cut

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return 1 if $Param{Name} eq "GroupID";
    return 1 if $Param{Name} =~ m{\A(DynamicField_.+)|(Article_DynamicField_.+)};

    if ( $Param{Name} =~ m{\AArticle_(.+)} ) {
        my $SearchArticleObject         = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
        my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIME');

        if ( !$Param{NoMappingCheck} ) {
            return 1 if $SearchArticleObject->{Fields}->{$1};
            return 1 if $SearchArticleDataMIMEObject->{Fields}->{$1};
        }
    }

    # by default check if field is in index fields and mapping check is enabled
    return if !$Self->{IndexFields}->{ $Param{Name} } && !$Param{NoMappingCheck};

    return 1;
}

=head2 _QueryFieldReturnTypeSet()

check specified return type field for index

    my $Result = $SearchQueryObject->_QueryFieldReturnTypeSet(
        Name => 'SLAID',
    );

=cut

sub _QueryFieldReturnTypeSet {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    if ( $Param{Name} =~ m{DynamicField_(.+)} ) {
        my $DynamicFieldName = $1;

        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $DynamicFieldName,
        );

        # possible that dynamic field config won't be available
        # on dynamic field delete events
        return if !IsHashRefWithData($DynamicFieldConfig);

        my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            FieldType          => 'Edit',
        );

        return $FieldValueType->{"DynamicField_$DynamicFieldName"} || 'SCALAR';
    }

    # return type is either specified or scalar
    return $Self->{IndexFields}->{ $Param{Name} }->{ReturnType} || 'SCALAR';
}

1;

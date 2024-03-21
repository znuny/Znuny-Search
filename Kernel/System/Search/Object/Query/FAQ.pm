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

    my $LookupFields = {
        CategoryShortName => {
            Module        => "Kernel::System::FAQ",
            FunctionName  => 'CategorySearch',
            ParamName     => 'Name',
            AttributeName => 'CategoryID'
        },
        Language => {},
        Valid    => {
            Module        => "Kernel::System::Valid",
            FunctionName  => 'ValidLookup',
            ParamName     => 'Valid',
            AttributeName => 'ValidID'
        },
        State         => {},
        StateTypeName => {},
    };

    return $LookupFields;
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

    my $FAQObject         = $Kernel::OM->Get('Kernel::System::FAQ');
    my $DBObject          = $Kernel::OM->Get('Kernel::System::DB');
    my $LookupFields      = $Self->LookupFAQFieldsGet();
    my $LookupQueryParams = {};

    # get lookup fields that exists in "QueryParams" parameter
    my %UsedLookupFields = map { $_ => $LookupFields->{$_} }
        grep { $LookupFields->{$_} }
        keys %{ $Param{QueryParams} };

    # support language
    my $LanguageLookupField = delete $UsedLookupFields{Language};
    if ($LanguageLookupField) {
        my $Param = delete $Param{QueryParams}->{Language};

        if ( defined $Param ) {

            my %Languages = reverse $FAQObject->LanguageList(
                UserID => 1,
            );

            my $Result = $Self->_LookupFieldWithTypeList(
                Param        => $Param,
                List         => \%Languages,
                ListToAppend => $LookupQueryParams,
                Attribute    => 'LanguageID',
            );

            return $Result if ref $Result eq 'HASH' && $Result->{Error};
        }
    }

    # support state
    my $StateLookupField = delete $UsedLookupFields{State};
    if ($StateLookupField) {
        my $Param = delete $Param{QueryParams}->{State};

        if ( defined $Param ) {
            my %States = reverse $FAQObject->StateList(
                UserID => 1,
            );

            my $Result = $Self->_LookupFieldWithTypeList(
                Param        => $Param,
                List         => \%States,
                ListToAppend => $LookupQueryParams,
                Attribute    => 'StateID',
            );

            return $Result if ref $Result eq 'HASH' && $Result->{Error};
        }
    }

    LOOKUPFIELD:
    for my $Key ( sort keys %UsedLookupFields ) {

        my $Param = delete $Param{QueryParams}->{$Key};
        next LOOKUPFIELD if ( !defined $Param );

        # lookup every field for ID
        my $LookupField   = $LookupFields->{$Key};
        my $Module        = $Kernel::OM->Get( $LookupField->{Module} );
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
                "$ParamName" => $Value,
                UserID       => 1,
            );

            next VALUE if !$FieldID;
            if ( ref $FieldID eq 'ARRAY' ) {
                push @IDs, @{$FieldID};
            }
            else {
                push @IDs, $FieldID;
            }

        }

        if ( !@IDs ) {
            return {
                Error => 'LookupValuesNotFound'
            };
        }

        my $LookupQueryParam = {
            Operator   => "=",
            Value      => \@IDs,
            ReturnType => 'SCALAR',
            Type       => 'Integer',
        };

        $LookupQueryParams->{$AttributeName} = $LookupQueryParam;
    }

    return $LookupQueryParams;
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryFAQObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
        QueryFor      => 'SQL', # also possible "Engine"
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
            ItemID => -1,
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

=head2 _LookupFieldWithTypeList()

perform lookup for fields with list functions

    my $FunctionResult = $Object->_LookupFieldWithTypeList(
        Param           => ['valid'],
        List            => { valid => 1, invalid => 0 },
        ListToAppend    => {},
        Attribute       => 'ValidID',
    );

=cut

sub _LookupFieldWithTypeList {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Param List ListToAppend Attribute)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my @Param = IsString( $Param{Param} )
        ?
        ( $Param{Param} )
        : @{ $Param{Param} };

    my @IDs;

    VALUE:
    for my $Value (@Param) {
        next VALUE if !defined $Value;
        my $FieldID = $Param{List}->{$Value};

        next VALUE if !$FieldID;
        push @IDs, $FieldID;
    }

    if ( !@IDs ) {
        return {
            Error => 'LookupValuesNotFound'
        };
    }

    # if there was some filter already applied
    # it needs to match currect and previous one (AND connection)
    if ( IsArrayRefWithData( $Param{ListToAppend}->{ $Param{Attribute} }->{Value} ) ) {

        # get previous filter
        my @PreviousFilter = @{ $Param{ListToAppend}->{ $Param{Attribute} }->{Value} };

        # check if current filter matches previous filter
        for ( my $i = 0; $i < scalar @PreviousFilter; $i++ ) {
            my $ID       = $PreviousFilter[$i];
            my @IDsMatch = grep { $_ == $ID } @IDs;

            # previous filter do not match currect filter
            if ( !scalar @IDsMatch ) {
                delete $Param{ListToAppend}->{ $Param{Attribute} }->{Value}->[$i];
            }

            # otherwise it matches and nothing needs to be done
        }
        @{ $Param{ListToAppend}->{ $Param{Attribute} }->{Value} }
            = grep {$_} @{ $Param{ListToAppend}->{ $Param{Attribute} }->{Value} };
    }

    $Param{ListToAppend}->{ $Param{Attribute} } = {
        Operator   => "=",
        Value      => \@IDs,
        ReturnType => 'SCALAR',
        Type       => 'Integer',
    };

    return 1;
}

1;

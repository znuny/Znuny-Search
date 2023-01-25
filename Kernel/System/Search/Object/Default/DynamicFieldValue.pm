# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::DynamicFieldValue;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
    'Kernel::System::Log',
    'Kernel::System::Search::Object',
    'Kernel::System::Search::Object::Query::DynamicFieldValue',
);

=head1 NAME

Kernel::System::Search::Object::Default::DynamicFieldValue - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchDynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::DynamicFieldValue');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check for engine package for this object
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{Engine} = $SearchObject->{Config}->{ActiveEngine} || 'ES';

    my $Loaded = $MainObject->Require(
        "Kernel::System::Search::Object::$Self->{Engine}::DynamicFieldValue",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::DynamicFieldValue") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::DynamicFieldValue";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'dynamic_field_value',    # index name on the engine/sql side
        IndexName     => 'DynamicFieldValue',      # index name on the api side
        Identifier    => 'ID',                     # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        ObjectID => {
            ColumnName => 'object_id',
            Type       => 'Integer'
        },
        FieldID => {
            ColumnName => 'field_id',
            Type       => 'String'
        },
        Value => {
            ColumnName => 'value',
            Type       => 'String',
            ReturnType => 'ARRAY',
        },
    };

    $Self->{Config}->{AdditionalZnunyFields} = {
        ValueText => {
            ColumnName => 'value_text',
            Type       => 'String'
        },
        ValueDate => {
            ColumnName => 'value_date',
            Type       => 'String'
        },
        ValueInt => {
            ColumnName => 'value_int',
            Type       => 'String'
        }
    };

    # get default config
    $Self->DefaultConfigGet();

    # load fields with custom field mapping
    $Self->_Load(
        Fields => $FieldMapping,
        Config => $Self->{Config},
    );

    return $Self;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchTicketESObject->ValidFieldsPrepare(
        Object => $ObjectName,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    NEEDED:
    for my $Needed (qw(Object)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Object}");

    my $Fields                = $IndexSearchObject->{Fields};
    my $AdditionalZnunyFields = $IndexSearchObject->{Config}->{AdditionalZnunyFields};

    my %ValidFields;

    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %ValidFields = ( %{$Fields}, %{$AdditionalZnunyFields} );
        delete $ValidFields{Value} if ( $Param{Fallback} );

        return $SearchChildObject->_PostValidFieldsPrepare(
            ValidFields => \%ValidFields,
        );
    }

    %{$Fields} = ( %{$Fields}, %{$AdditionalZnunyFields} );

    FIELD:
    for my $ParamField ( @{ $Param{Fields} } ) {
        if ( $ParamField =~ m{^$Param{Object}_(.+)$} ) {
            my $Field = $1;

            if ( $Fields->{$Field} ) {
                $ValidFields{$Field} = $Fields->{$Field};
            }
            elsif ( $Field eq '*' ) {
                %ValidFields = %{$Fields};
            }
        }
    }

    return $SearchChildObject->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
    );
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchBaseObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
        },
        Fields      => ['ObjectID', 'FieldID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10,
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $QueryDynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::DynamicFieldValue');

    my $ConvertResponse;
    my $Fields = $Param{Fields};

    if ( IsHashRefWithData($Fields) ) {
        my %Fields = %{$Fields};
        $Fields = [];
        @{$Fields} = keys %{ $Param{Fields} };
    }
    elsif ( !$Fields || !IsArrayRefWithData($Fields) ) {
        @{$Fields} = keys %{ $Self->{Fields} };
    }

    my @SQLSearchFields   = keys %{ $Self->{Config}->{AdditionalZnunyFields} };
    my %CustomIndexFields = ( %{ $Self->{Fields} }, %{ $Self->{Config}->{AdditionalZnunyFields} } );
    delete $CustomIndexFields{Value};
    for my $Field ( sort keys %{ $Self->{Fields} } ) {
        if ( $Field ne 'Value' ) {
            push @SQLSearchFields, $Field;
        }
    }

    my %AdditionalFields = %{ $Self->{Config}->{AdditionalZnunyFields} };

    # handle denormalized value field
    if ( IsArrayRefWithData($Fields) ) {
        FIELD:
        for ( my $i = 0; $i < scalar @{$Fields}; $i++ ) {
            next FIELD if $Fields->[$i] ne 'Value';

            delete $Fields->[$i];

            for my $Field ( sort keys %AdditionalFields ) {
                push @{$Fields}, $Field;
            }

            @{$Fields} = grep {$_} @{$Fields};
            last FIELD;
        }
    }

    my $ResultType = $Param{ResultType};

    if ( $ResultType eq 'COUNT' ) {
        $ResultType      = 'ARRAY';
        @SQLSearchFields = keys %AdditionalFields;
        push @SQLSearchFields, 'ID';
        push @SQLSearchFields, 'FieldID';
        push @SQLSearchFields, 'ObjectID';
    }

    my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(
        %Param,
        Fields            => \@SQLSearchFields,
        CustomIndexFields => \%CustomIndexFields,
        ResultType        => $ResultType,
    );

    return $SQLSearchResult if !$SQLSearchResult->{Success} || !IsArrayRefWithData( $SQLSearchResult->{Data} );

    $SQLSearchResult->{Data} = $QueryDynamicFieldValueObject->_PrepareDFSQLResponse(
        SQLSearchResult => $SQLSearchResult->{Data},
        Index           => 'DynamicFieldValue',
    );

    if ( IsHashRefWithData( $Param{Fields} ) ) {
        for my $ValueColumn (qw(ValueText ValueDate ValueInt)) {
            delete $Param{Fields}->{$ValueColumn};
        }
    }
    elsif ( IsArrayRefWithData( $Param{Fields} ) ) {
        for ( my $i = 0; $i < scalar @{ $Param{Fields} }; $i++ ) {
            if ( $Param{Fields}->[$i] =~ m{^(ValueText|ValueDate|ValueInt)$} ) {
                delete $Param{Fields}->[$i];
            }
        }
        @{ $Param{Fields} } = grep {$_} @{ $Param{Fields} };
    }

    if ( $Param{ResultType} eq 'COUNT' ) {
        return {
            Data    => scalar @{ $SQLSearchResult->{Data} },
            Success => $SQLSearchResult->{Success},
        };
    }

    return $SQLSearchResult;
}

1;

# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Base;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::Config',
);

=head1 NAME

Kernel::System::Search::Object::Base - common base backend functions

=head1 DESCRIPTION

Proceed with fallback, format operation response, load custom columns and
other base related functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchBaseObject = $Kernel::OM->Get('Kernel::System::Search::Object::Base');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "Constructor needs to be overriden!",
    );

    return $Self;
}

=head2 Fallback()

Fallback from using advanced search for specific index.

Should return same response as advanced search
engine globally formatted response.

    my $Result = $SearchBaseObject->Fallback(
        QueryParams => {
            TicketID => 1,
        },
    );

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( QueryParams )) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $SQLSearchResult = $Self->SQLObjectSearch(
        QueryParams => $Param{QueryParams},
    );

    my $Result = {
        EngineData => {},
        ObjectData => $SQLSearchResult,
    };

    return $Result;
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchBaseObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
        },
        Fields => ['id', 'sla_id'] # optional, returns all
                                   # fields if not specified
        OrderBy => $IdentifierSQL,
        OrderDirection => "Down",  # possible: "DESC", "ASC"
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( QueryParams )) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $IndexRealName = $Self->{Config}->{IndexRealName};
    my $Fields        = $Self->{Fields};

    my @TableColumns;

    if ( IsArrayRefWithData( $Param{Fields} ) ) {
        @TableColumns = @{ $Param{Fields} };
    }
    else {
        @TableColumns = values %{$Fields};
    }

    # prepare sql statement
    my $SQL = 'SELECT ' . join( ',', @TableColumns ) . ' FROM ' . $IndexRealName;

    if ( IsHashRefWithData( $Param{QueryParams} ) ) {
        my @QueryConditions;
        PARAM:
        for my $QueryParam ( sort keys %{ $Param{QueryParams} } ) {

            # check if there is existing mapping between query param and database column
            next PARAM if !$Fields->{$QueryParam};

            if ( $Param{QueryParams}->{$QueryParam} eq '' ) {
                push @QueryConditions, "$Fields->{$QueryParam} IS NULL";
                next PARAM;
            }

            push @QueryConditions, "$Fields->{$QueryParam} = '$Param{QueryParams}->{$QueryParam}'";
        }

        $SQL .= ' WHERE ' . join( ' AND ', @QueryConditions );
    }

    if ( $Param{OrderBy} ) {
        $SQL .= " ORDER BY $Param{OrderBy}";
        if ( $Param{OrderDirection} ) {
            $SQL .= " $Param{OrderDirection}";
        }
    }

    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    my @Result;

    # save data in format: sql column name => sql column value
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my %Data;
        my $DataCounter = 0;
        for my $RealNameColumn (@TableColumns) {
            $Data{$RealNameColumn} = $Row[$DataCounter];
            $DataCounter++;
        }
        push @Result, \%Data;
    }

    return \@Result;
}

=head2 SearchFormat()

format result specifically for index

    my $FormattedResult = $SearchBaseObject->SearchFormat(
        ResultType => 'ARRAY|HASH|COUNT' (optional, default: 'ARRAY')
        IndexName  => "Ticket",
        GloballyFormattedResult => $GloballyFormattedResult,
    )

=cut

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # return array ref as default
    $Param{ResultType} ||= 'ARRAY';

    # define supported result types
    my $SupportedResultType = {
        'ARRAY' => 1,
        'HASH'  => 1,
        'COUNT' => 1,
    };

    if ( !$SupportedResultType->{ $Param{ResultType} } ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Specified result type: $Param{ResultType} isn't supported! Default value: \"ARRAY\" will be used instead.",
        );

        # revert to default result type
        $SupportedResultType = 'ARRAY';
    }

    my $IndexName               = $Self->{Config}->{IndexName};
    my $GloballyFormattedResult = $Param{GloballyFormattedResult};

    OBJECT:
    for my $ObjectData ( @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} } ) {
        ATTRIBUTE:
        for my $ObjectAttribute ( sort keys %{$ObjectData} ) {

            my @AttributeName = grep { $Self->{Fields}->{$_} eq $ObjectAttribute } keys %{ $Self->{Fields} };
            next ATTRIBUTE if !$AttributeName[0];

            $ObjectData->{ $AttributeName[0] } = $ObjectData->{$ObjectAttribute};

            delete $ObjectData->{$ObjectAttribute};
        }
    }

    my $IndexResponse;

    if ( $Param{ResultType} eq "COUNT" ) {
        $IndexResponse->{$IndexName} = scalar @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} };
    }
    elsif ( $Param{ResultType} eq "ARRAY" ) {
        $IndexResponse->{$IndexName} = $GloballyFormattedResult->{$IndexName}->{ObjectData};
    }
    elsif ( $Param{ResultType} eq "HASH" ) {
        my $Identifier = $Self->{Config}->{Identifier};
        if ( !$Identifier ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Missing '\$Self->{Config}->{Identifier} for $IndexName index.'",
            );
            return;
        }

        DATA:
        for my $Data ( @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} } ) {
            if ( !$Data->{$Identifier} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Could not get object identifier: $Identifier for index: $IndexName in the response!",
                );
                next DATA;
            }

            $IndexResponse->{$IndexName}->{ $Data->{$Identifier} } = $Data;
        }
    }

    return $IndexResponse;
}

sub IndexObjectGetFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

sub IndexObjectAddFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

sub IndexObjectRemoveFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchTicketObject->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $IndexObject   = $Kernel::OM->Get("Kernel::System::Search::Object::$Self->{Config}->{IndexName}");
    my $Identifier    = $IndexObject->{Config}->{Identifier};
    my $IdentifierSQL = $IndexObject->{Fields}->{$Identifier};

    # search for all objects from newest, order it by id
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams    => {},
        Fields         => [$IdentifierSQL],
        OrderDirection => "DESC",
        OrderBy        => $IdentifierSQL,
    );

    my @Result = ();

    # push hash data into array
    if ( IsArrayRefWithData($SQLSearchResult) ) {
        for my $SQLData ( @{$SQLSearchResult} ) {
            push @Result, $SQLData->{$IdentifierSQL};
        }
    }

    return \@Result;
}

=head2 CustomFieldsConfig()

get all registered custom field mapping for parent index module or specified in parameter index

    $Config = $SearchBaseObject->CustomFieldsConfig(
        Index => $Index # Optional
    );

=cut

sub CustomFieldsConfig {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{Config}->{IndexName} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need IndexName!",
        );
    }

    my $CustomPackageModuleConfigList = $ConfigObject->Get("Search::FieldsLoader::$Self->{Config}->{IndexName}}");

    my %CustomFieldsMapping;

    for my $CustomPackageConfig ( sort keys %{$CustomPackageModuleConfigList} ) {
        my $Module        = $CustomPackageModuleConfigList->{$CustomPackageConfig};
        my $PackageModule = $Kernel::OM->Get("$Module->{Module}");

        %CustomFieldsMapping = ( %{ $PackageModule->{Fields} }, %CustomFieldsMapping );
    }

    return \%CustomFieldsMapping;
}

1;

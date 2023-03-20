# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::EngineQueryHelper::ES;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::JSON',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Object::EngineQueryHelper::ES - search engine EngineQueryHelper lib

=head1 DESCRIPTION

Common search engine EngineQueryHelper backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $EngineQueryHelper = $Kernel::OM->Get('Kernel::System::Search::Object::EngineQueryHelper::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{IndexName} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter 'IndexName' is needed!",
        );
        return {};
    }

    my $IsValid = $SearchChildObject->IndexIsValid(
        IndexName => $Param{IndexName},
    );

    if ( !$IsValid ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Specified index is not valid!",
        );
        return {};
    }

    $Self->{IndexName}     = $Param{IndexName};
    $Self->{Query}         = $Param{Query} || {};
    $Self->{MappingObject} = $SearchObject->{MappingIndexObject}->{ $Param{IndexName} };
    $Self->{QueryObject}   = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{IndexName}");
    $Self->{IndexObject}   = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{IndexName}");
    $Self->{EngineObject}  = $SearchObject->{EngineObject};
    $Self->{ConnectObject} = $SearchObject->{ConnectObject};

    return $Self;
}

=head2 QueryUpdate()

update engine query based on query parameters

    my $Success = $EngineQueryHelper->QueryUpdate(
        QueryParams => $QueryParams,
        Strict => 1, # make sure every query will be applied
    );

=cut

sub QueryUpdate {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData( $Param{QueryParams} );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $SearchParams = $Self->{QueryObject}->_QueryParamsPrepare(
        QueryParams   => $Param{QueryParams},
        NoPermissions => $Param{NoPermissions},
        QueryFor      => 'Engine',
    );

    my $SearchParamsCount = keys %{$SearchParams};
    my $QueryParamsCount  = keys %{ $Param{QueryParams} };

    my $Success = 1;
    if ( $Param{Strict} ) {
        $Success = !$SearchParams->{Error} && ( $SearchParamsCount == $QueryParamsCount );
    }
    if ( IsHashRefWithData($SearchParams) && $Success ) {
        SEARCH_PARAM:
        for my $Field ( sort keys %{$SearchParams} ) {
            my $SuccessLocal = $Self->{MappingObject}->_AppendQueryBodyFromParams(
                QueryParams => $SearchParams,
                Query       => $Self->{Query},
                Object      => $Self->{IndexName},
            );
            if ( $Param{Strict} && !$SuccessLocal ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Parameter '$Field' could not be applied into query!",
                );

                $Success = 0;
                last SEARCH_PARAM;
            }
        }
    }

    if ( !$Success ) {
        $Self->{Error}->{Strict}->{QueryUpdate} = 1;
    }

    return $Success;
}

=head2 QueryExecute()

execute query

    my $Result = $EngineQueryHelper->QueryExecute();

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    my $Response = $Self->{EngineObject}->QueryExecute(
        ConnectObject => $Self->{ConnectObject},
        Query         => $Self->{Query},
        Operation     => $Param{Operation} || 'Generic',
    );

    return $Response;
}

=head2 QueryApplyLimit()

apply limit query

    my $SuccessCode = $EngineQueryHelper->QueryApplyLimit(
        Limit => 1000,
    );

=cut

sub QueryApplyLimit {
    my ( $Self, %Param ) = @_;

    my $LimitQuery = $Self->{MappingObject}->LimitQueryBuild(
        Limit     => $Param{Limit},
        IndexName => $Self->{IndexName},
    );

    if ( $LimitQuery->{Success} ) {
        %{ $Self->{Query}->{Body} } = ( %{ $Self->{Query}->{Body} }, %{ $LimitQuery->{Query} } );
    }
    elsif ( $Param{Strict} ) {
        $Self->{Error}->{Strict}->{ApplyLimit} = 1;
    }

    return $LimitQuery->{Success};
}

=head2 QueryApplySortBy()

apply limit query

    my $SuccessCode = $EngineQueryHelper->QueryApplySortBy(
        Limit => 1000,
    );

=cut

sub QueryApplySortBy {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(SortBy OrderBy ResultType)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $SortBy = $Self->{IndexObject}->SortParamApply(
        SortBy     => $Param{SortBy},
        ResultType => $Param{ResultType},
    );

    $SortBy->{OrderBy} = $Param{OrderBy};

    my $SortByQuery = $Self->{MappingObject}->SortByQueryBuild(
        SortBy => $SortBy,
        Strict => $Param{Strict},
    );

    if ( $SortByQuery->{Success} ) {
        push @{ $Self->{Query}->{Body}->{sort} }, $SortByQuery->{Query};
    }
    elsif ( $Param{Strict} ) {
        $Self->{Error}->{Strict}->{ApplySortBy} = 1;
    }

    return $SortByQuery->{Success};
}

=head2 QueryValidate()

validate query

    my $Success = $EngineQueryHelper->QueryValidate();

=cut

sub QueryValidate {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');

    if ( IsHashRefWithData( $Self->{Error} ) ) {
        my $JSON = $JSONObject->Encode(
            Data => { Error => $Self->{Error} },
        );

        $LogObject->Log(
            Priority => 'error',
            Message  => "There was an error when trying to create engine query! Error details: $JSON",
        ) if !$Param{Silent};

        return;
    }
    return 1;
}

1;

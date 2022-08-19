# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
use Kernel::System::Search;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    # prevent using constructor that checks search engine
    # as it's not needed here
    $Self->{Engines} = Kernel::System::Search->EngineListGet();

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $ClusterID = $ParamObject->GetParam( Param => 'ClusterID' ) || '';

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');

    if ( $Self->{Subaction} eq 'Change' ) {

        # check for ClusterID
        if ( !$ClusterID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ClusterID !'),
            );
        }

        # get cluster configuration
        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $ClusterID,
        );

        # check for valid cluster configuration
        if ( !IsHashRefWithData($ClusterData) ) {
            return $LayoutObject->ErrorScreen(
                Message =>
                    $LayoutObject->{LanguageObject}->Translate( 'Could not get data for ClusterID %s', $ClusterID ),
            );
        }

        return $Self->_ShowEdit(
            %Param,
            ClusterID   => $ClusterID,
            ClusterData => $ClusterData,
            Action      => 'Change',
        );
    }
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        $LayoutObject->ChallengeTokenCheck();

        my $GetParam = $Self->_GetBaseParams();

        if ( !$ClusterID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ClusterID !'),
            );
        }

        my %ClusterData;

        for my $Property (qw(Name RemoteSystem ValidID Description EngineID)) {
            $ClusterData{$Property} = $GetParam->{$Property};
        }

        $ClusterData{UserID} = $Self->{UserID};

        my %Error;
        my $Exists;

        if ( !$ClusterData{Name} ) {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('This field is required.');
        }
        else {
            # check if name is duplicated
            $Exists = $SearchClusterObject->NameExistsCheck(
                ID   => $ClusterID,
                Name => $ClusterData{Name},
            );
        }

        if ( !$ClusterData{RemoteSystem} ) {

            # add server error error class
            $Error{RemoteSystemError}   = 'ServerError';
            $Error{RemoteSystemMessage} = Translatable('This field is required.');
        }

        if ( !$ClusterData{RemoteSystem} ) {

            # add server error error class
            $Error{EngineIDError}   = 'ServerError';
            $Error{EngineIDMessage} = Translatable('This field is required.');
        }

        if ($Exists)
        {
            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('There is another cluster with the same name.');
        }

        # if there is an error return to edit screen
        if (%Error) {
            return $Self->_ShowEdit(
                %Error,
                %Param,
                ClusterID   => $ClusterID,
                ClusterData => \%ClusterData,
                Action      => 'Change',
                Error       => 1,
            );
        }

        my $Success = $SearchClusterObject->ClusterUpdate(
            ClusterID => $ClusterID,
            %{$GetParam},
        );

        # show error if cant update
        if ( !$Success ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('There was an error updating the web service.'),
            );
        }

        if (
            defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
            && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
            )
        {

            # if the user would like to continue editing the ACL, just redirect to the edit screen
            return $LayoutObject->Redirect(
                OP =>
                    "Action=AdminSearch;Subaction=Change;ClusterID=$ClusterID"
            );
        }
        else {

            # otherwise return to overview
            return $LayoutObject->Redirect( OP => "Action=$Self->{Action}" );
        }
    }

    if ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_ShowEdit(
            Action => 'Add',
        );

    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get cluster configuration
        my $ClusterData;

        # get parameter from web browser
        my $GetParam = $Self->_GetBaseParams();

        # set new configuration
        $ClusterData->{Name}         = $GetParam->{Name};
        $ClusterData->{Description}  = $GetParam->{Description};
        $ClusterData->{RemoteSystem} = $GetParam->{RemoteSystem};
        $ClusterData->{EngineID}     = $GetParam->{EngineID};
        $ClusterData->{ValidID}      = $GetParam->{ValidID};

        my %Error;
        my $Exists;

        if ( !$GetParam->{Name} ) {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('This field is required.');
        }
        else {
            # check if name is duplicated
            $Exists = $SearchClusterObject->NameExistsCheck(
                ID   => $ClusterID,
                Name => $GetParam->{Name},
            );
        }

        if ( !$GetParam->{RemoteSystem} ) {

            # add server error error class
            $Error{RemoteSystemError}        = 'ServerError';
            $Error{RemoteSystemErrorMessage} = Translatable('This field is required.');
        }

        if ( !$GetParam->{EngineID} ) {

            # add server error error class
            $Error{EngineIDError}        = 'ServerError';
            $Error{EngineIDErrorMessage} = Translatable('This field is required.');
        }

        if ($Exists)
        {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('There is another cluster with the same name.');
        }

        # if there is an error return to edit screen
        if (%Error) {
            return $Self->_ShowEdit(
                %Error,
                %Param,
                ClusterID   => $ClusterID,
                ClusterData => $ClusterData,
                Action      => 'Add',
                Error       => 1,
            );
        }

        # otherwise save configuration and return to overview screen
        my $ID = $SearchClusterObject->ClusterAdd(
            Name         => $ClusterData->{Name},
            RemoteSystem => $ClusterData->{RemoteSystem},
            ValidID      => $ClusterData->{ValidID},
            Description  => $ClusterData->{Description},
            EngineID     => $ClusterData->{EngineID},
            UserID       => $Self->{UserID},
        );

        # show error if cant create
        if ( !$ID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('There was an error creating the cluster.'),
            );
        }

        # set ClusterID to the new created cluster
        $ClusterID = $ID;

        # define notification
        my $Notify = $LayoutObject->{LanguageObject}->Translate(
            'Cluster "%s" created!',
            $ClusterData->{Name},
        );

        $Self->_ClusterSynchronize(
            ClusterID => $ClusterID
        );

        # return overview
        return $Self->_ShowOverview(
            %Param,
            Notify => $Notify,
            Action => 'Overview'
        );
    }
    elsif ( $Self->{Subaction} eq 'DeleteAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get cluster configuration
        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $ClusterID,
        );

        my $Success = $SearchClusterObject->ClusterDelete(
            ClusterID => $ClusterID,
            UserID    => $Self->{UserID},
        );

        # build JSON output
        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success        => $Success,
                DeletedCluster => $ClusterData->{Name},
            },
        );

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'SynchronizeAction' ) {

        return $Self->_ClusterSynchronize(
            ClusterID => $ClusterID,
        );

    }

    my $DeletedCluster = $ParamObject->GetParam( Param => 'DeletedCluster' ) || '';

    my $Notify;

    if ($DeletedCluster) {

        # define notification
        $Notify = $LayoutObject->{LanguageObject}->Translate(
            'Cluster "%s" deleted!',
            $DeletedCluster,
        );

    }

    return $Self->_ShowOverview(
        %Param,
        Notify => $Notify,
        Action => 'Overview',
    );
}

sub _ShowOverview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $SearchObject        = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject          = $Kernel::OM->Get('Kernel::System::Main');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    if ( $Param{Notify} ) {
        $Output .= $LayoutObject->Notify(
            Info => $Param{Notify},
        );
    }

    if ( !$SearchObject->{Config}->{Enabled} ) {
        $Output .= $LayoutObject->Notify(
            Info     => 'Please activate search engine first!',
            Priority => 'Error',
            Link => $LayoutObject->{Baselink} . 'Action=AdminSystemConfiguration;Subaction=View;Setting=SearchEngine;'
        );
    }

    # call all needed template blocks
    $LayoutObject->Block(
        Name => 'Main',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionAdd' );
    $LayoutObject->Block( Name => 'OverviewHeader' );
    $LayoutObject->Block( Name => 'OverviewResult' );

    my $ClusterList = $SearchClusterObject->ClusterList(
        Valid => 0,
    );

    if ( !IsHashRefWithData($ClusterList) ) {
        $LayoutObject->Block( Name => 'NoDataFoundMsg' );
    }
    else {
        CLUSTER:
        for my $ClusterID (
            sort { $ClusterList->{$a} cmp $ClusterList->{$b} }
            keys %{$ClusterList}
            )
        {
            next CLUSTER if !$ClusterID;

            my $Cluster = $SearchClusterObject->ClusterGet( ClusterID => $ClusterID );
            next CLUSTER if !$Cluster;

            # convert ValidID to text
            my $ValidStrg = $ValidObject->ValidLookup(
                ValidID => $Cluster->{ValidID},
            );

            if ( !$Cluster->{RemoteSystem} ) {

                # write an error message to the OTRS log
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Configuration of ClusterID $ClusterID is invalid!",
                );

                $Output .= $LayoutObject->Notify(
                    Priority => 'Error',
                );

                next CLUSTER;
            }

            # Engine isn't in the configuration
            if ( !$Self->{Engines}->{ $Cluster->{EngineID} } ) {
                $Self->{Engines}->{ $Cluster->{EngineID} } = 'Unregistered';
            }

            # prepare data to output
            my $Data = {
                ID           => $ClusterID,
                Name         => $Cluster->{Name},
                Description  => $Cluster->{Description} || '-',
                RemoteSystem => $Cluster->{RemoteSystem} || '-',
                Engine       => $Self->{Engines}->{ $Cluster->{EngineID} },
                Valid        => $ValidStrg,
            };

            $LayoutObject->Block(
                Name => 'OverviewResultRow',
                Data => $Data,
            );
        }
    }

    my $ConnectObject;

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::System::Search'],
    );

    $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my $ActiveClusterConfig = $SearchClusterObject->ActiveClusterGet();

    if ( $SearchObject->{EngineObject} ) {
        $ConnectObject = $SearchObject->{EngineObject}->Connect( Config => $SearchObject->{Config} );
    }
    elsif ( $SearchObject->{Config}->{ActiveEngine} ) {
        my $Loaded = $MainObject->Require(
            "Kernel::System::Search::Engine::$SearchObject->{Config}->{ActiveEngine}",
            Silent => $Param{Silent},
        );
        if ($Loaded) {
            my $EngineObject
                = $Kernel::OM->Get("Kernel::System::Search::Engine::$SearchObject->{Config}->{ActiveEngine}");
            $ConnectObject = $EngineObject->Connect( Config => $SearchObject->{Config} );
        }
        else {
            $ConnectObject->{Error} = 1;
        }
    }

    if ( !$SearchObject->{Config}->{ActiveEngine} || $SearchObject->{Config}->{ActiveEngine} eq 'Unregistered' ) {
        $LayoutObject->Block(
            Name => 'Status',
            Data => {
                ClusterName       => $ActiveClusterConfig->{Name},
                ConnectionMessage => 'Engine of the active cluster is not registered!',
                ConnectionStatus  => 'Failed',
            },
        );
    }
    else {
        my $ConnectionStrg   = $ConnectObject->{Error} ? 'failed' : 'available';
        my $ConnectionStatus = $ConnectObject->{Error} ? 'Failed' : 'Available';

        $LayoutObject->Block(
            Name => 'Status',
            Data => {
                ClusterName           => $ActiveClusterConfig->{Name},
                ConnectionMessage     => $ConnectionStrg,
                ConnectionStatus      => $ConnectionStatus,
                SearchEngineIsRunning => IsHashRefWithData( $SearchObject->{Error} ) ? 0 : 1,
            },
        );
    }

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminSearch',
        Data         => {
            %Param,
        },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _ShowEdit {
    my ( $Self, %Param ) = @_;

    my $ClusterData = $Param{ClusterData};

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $SearchObject        = $Kernel::OM->Get('Kernel::System::Search');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # show notifications if any
    if ( $Param{Notify} ) {
        $Output .= $LayoutObject->Notify(
            Info => $Param{Notify},
        );
    }

    $LayoutObject->Block(
        Name => 'Main',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );

    if ( $Param{Action} eq 'Change' ) {
        $LayoutObject->Block(
            Name => 'ActionDelete',
            Data => \%Param,
        );
    }

    my %GeneralData = (
        Name         => $ClusterData->{Name},
        Description  => $ClusterData->{Description},
        RemoteSystem => $ClusterData->{RemoteSystem},
    );

    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my %ValidList   = $ValidObject->ValidList();

    # create the validity select
    my $ValidtyStrg = $LayoutObject->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $ClusterData->{ValidID} || 1,
        PossibleNone => 0,
        Translate    => 1,
        Class        => 'Modernize',
    );

    # create the validity select
    my $EngineStrg = $LayoutObject->BuildSelection(
        Data         => $Self->{Engines},
        Name         => 'EngineID',
        SelectedID   => $ClusterData->{Engine},
        PossibleNone => 0,
        Translate    => 1,
        Class        => 'Modernize Validate_Required',
    );

    # prevent HTML validation warning
    if ( !$Param{NameServerErrorMessage} ) {
        $Param{NameServerErrorMessage} = '-';
    }

    $LayoutObject->Block(
        Name => 'Details',
        Data => {
            %Param,
            %GeneralData,
            ValidtyStrg => $ValidtyStrg,
            EngineStrg  => $EngineStrg,
        },
    );

    my $ActiveClusterConfig = $SearchClusterObject->ActiveClusterGet();

    my $SearchObjectCheckError = $SearchObject->{Error};

    if (
        !$SearchObjectCheckError
        && !$Param{Error}
        && $Self->{Subaction} ne "Add"
        && $ClusterData->{ClusterID}
        && $ClusterData->{ClusterID} eq $ActiveClusterConfig->{ClusterID}
        )
    {

        my $ClusterDetailsObject
            = $Kernel::OM->Get("Kernel::System::Search::Admin::Details::$ActiveClusterConfig->{Engine}");

        my $Details = $ClusterDetailsObject->BuildDetailsSection(
            ClusterConfig => $ActiveClusterConfig,
            UserID        => $Self->{UserID}
        );

        if ( IsHashRefWithData($Details) && $Details->{Changes} && $SearchObject->{ConnectObject} ) {
            $LayoutObject->Block(
                Name => 'ActionSynchronize',
                Data => {},
            );

            $Output .= $LayoutObject->Notify(
                Info => 'Cluster state needs to be synchronized!',
            );
        }

        $LayoutObject->Block(
            Name => 'DiagnosisDetails',
            Data => {
                Details => $Details->{HTML},
            },
        );
    }
    elsif ($SearchObjectCheckError) {
        my $ErrorMessage;
        if ( $SearchObjectCheckError->{Configuration}->{Disabled} ) {
            $ErrorMessage
                = $LayoutObject->{LanguageObject}->Translate("Search engine system configuration is disabled.");
        }
        elsif ( $SearchObjectCheckError->{Configuration}->{NoIndexRegistered} ) {
            $ErrorMessage = $LayoutObject->{LanguageObject}->Translate("No index registered for engine.");
        }
        elsif ( $SearchObjectCheckError->{Configuration}->{ActiveEngineNotFound} ) {
            $ErrorMessage = $LayoutObject->{LanguageObject}->Translate("Active engine not found.");
        }
        elsif ( $SearchObjectCheckError->{BaseModules}->{NotFound} ) {
            $ErrorMessage = $LayoutObject->{LanguageObject}->Translate("Base modules for engine was not found.");
        }
        elsif ( $SearchObjectCheckError->{Connection}->{Failed} ) {
            $ErrorMessage = $LayoutObject->{LanguageObject}->Translate("Connection failed.");
        }

        $LayoutObject->Block(
            Name => 'DiagnosisDetails',
            Data => {
                Details => $ErrorMessage
            },
        );

    }
    else {
        my $ErrorMessage = $LayoutObject->{LanguageObject}->Translate("Engine is not active.");
        $LayoutObject->Block(
            Name => 'DiagnosisDetails',
            Data => {
                Details => $ErrorMessage
            },
        );
    }

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminSearch',
        Data         => {
            %Param,
        },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _GetBaseParams {
    my ( $Self, %Param ) = @_;

    my $GetParam;
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get parameters from web browser
    for my $ParamName (
        qw( Name Description RemoteSystem ValidID EngineID )
        )
    {
        $GetParam->{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';
    }

    return $GetParam;
}

sub _ClusterSynchronize {

    my ( $Self, %Param ) = @_;

    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');

    NEEDED:
    for my $Needed (qw(ClusterID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    # challenge token check for write action
    $LayoutObject->ChallengeTokenCheck();

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my $ActiveClusterConfig = $SearchClusterObject->ActiveClusterGet();

    my $ClusterDetailsObject
        = $Kernel::OM->Get("Kernel::System::Search::Admin::Details::$ActiveClusterConfig->{Engine}");

    my $EngineClusterState = $SearchObject->DiagnosticDataGet();

    if ($EngineClusterState) {
        $ClusterDetailsObject->ClusterStateSet(
            ClusterID    => $Param{ClusterID},
            ClusterState => $EngineClusterState,
            UserID       => $Self->{UserID},
        );
    }

    my $Response = $JSONObject->Encode( Data => $ActiveClusterConfig );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $Response,
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;

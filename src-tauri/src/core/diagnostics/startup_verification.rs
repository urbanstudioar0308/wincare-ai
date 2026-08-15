use super::models::ActionResult;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VerificationExpectation {
    Active,
    Disabled,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerificationObservation {
    pub target_id: String,
    pub before_state: String,
    pub after_state: Option<String>,
    pub expected: VerificationExpectation,
    pub rollback_available: bool,
}

fn now_unix_seconds() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn normalize_state(value: &str) -> &str {
    match value.trim().to_ascii_lowercase().as_str() {
        "active" | "enabled" | "activo" | "habilitado" => "active",
        "disabled" | "inactive" | "desactivado" | "inhabilitado" => "disabled",
        _ => "unknown",
    }
}

fn expected_state(expectation: &VerificationExpectation) -> &'static str {
    match expectation {
        VerificationExpectation::Active => "active",
        VerificationExpectation::Disabled => "disabled",
    }
}

pub fn verify_action(
    action_id: impl Into<String>,
    observation: VerificationObservation,
) -> ActionResult {
    let action_id = action_id.into();
    let expected = expected_state(&observation.expected);
    let before = normalize_state(&observation.before_state).to_string();
    let after = observation
        .after_state
        .as_deref()
        .map(normalize_state)
        .map(str::to_string);

    let verified = after.as_deref() == Some(expected);
    let changed = after
        .as_deref()
        .map(|after_state| after_state != before)
        .unwrap_or(false);

    let message = if verified {
        format!("Cambio verificado: el estado final es {expected}.")
    } else if after.is_none() {
        "La accion se ejecuto, pero WinCare no pudo observar el estado posterior.".to_string()
    } else {
        format!(
            "La accion se ejecuto, pero el estado posterior no coincide con el esperado ({expected})."
        )
    };

    ActionResult {
        action_id,
        target_id: observation.target_id,
        success: verified,
        changed,
        before: Some(before),
        after,
        verified,
        rollback_available: observation.rollback_available,
        message,
        executed_at: now_unix_seconds(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn disable_is_success_only_when_post_state_is_disabled() {
        let result = verify_action(
            "startup.disable",
            VerificationObservation {
                target_id: "discord".to_string(),
                before_state: "active".to_string(),
                after_state: Some("disabled".to_string()),
                expected: VerificationExpectation::Disabled,
                rollback_available: true,
            },
        );

        assert!(result.success);
        assert!(result.changed);
        assert!(result.verified);
        assert_eq!(result.before.as_deref(), Some("active"));
        assert_eq!(result.after.as_deref(), Some("disabled"));
        assert!(result.rollback_available);
    }

    #[test]
    fn command_completion_without_expected_state_is_not_verified() {
        let result = verify_action(
            "startup.disable",
            VerificationObservation {
                target_id: "example".to_string(),
                before_state: "active".to_string(),
                after_state: Some("active".to_string()),
                expected: VerificationExpectation::Disabled,
                rollback_available: true,
            },
        );

        assert!(!result.success);
        assert!(!result.changed);
        assert!(!result.verified);
    }

    #[test]
    fn restore_requires_active_post_state() {
        let result = verify_action(
            "startup.restore",
            VerificationObservation {
                target_id: "spotify".to_string(),
                before_state: "disabled".to_string(),
                after_state: Some("enabled".to_string()),
                expected: VerificationExpectation::Active,
                rollback_available: false,
            },
        );

        assert!(result.success);
        assert!(result.changed);
        assert!(result.verified);
        assert_eq!(result.after.as_deref(), Some("active"));
    }

    #[test]
    fn missing_post_state_never_claims_success() {
        let result = verify_action(
            "startup.disable",
            VerificationObservation {
                target_id: "unknown".to_string(),
                before_state: "active".to_string(),
                after_state: None,
                expected: VerificationExpectation::Disabled,
                rollback_available: false,
            },
        );

        assert!(!result.success);
        assert!(!result.verified);
        assert!(result.after.is_none());
    }
}

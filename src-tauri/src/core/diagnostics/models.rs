use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Info,
    Ok,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Confidence {
    High,
    Medium,
    Low,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Impact {
    Performance,
    Stability,
    Storage,
    Startup,
    Hardware,
    Windows,
    Network,
    Maintenance,
    Security,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum RiskLevel {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Evidence {
    pub source: String,
    pub metric: String,
    pub value: String,
    pub expected: Option<String>,
    pub message: String,
    pub technical_data: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Recommendation {
    pub id: String,
    pub title: String,
    pub explanation: String,
    pub expected_impact: Option<String>,
    pub risk: RiskLevel,
    pub action_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Finding {
    pub id: String,
    pub module: String,
    pub title: String,
    pub description: String,
    pub severity: Severity,
    pub confidence: Confidence,
    pub impacts: Vec<Impact>,
    pub evidence: Vec<Evidence>,
    pub recommendations: Vec<Recommendation>,
    pub detected_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ActionResult {
    pub action_id: String,
    pub target_id: String,
    pub success: bool,
    pub changed: bool,
    pub before: Option<String>,
    pub after: Option<String>,
    pub verified: bool,
    pub rollback_available: bool,
    pub message: String,
    pub executed_at: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn diagnostic_models_serialize_with_stable_names() {
        let finding = Finding {
            id: "startup.loaded".to_string(),
            module: "startup".to_string(),
            title: "Inicio cargado".to_string(),
            description: "Prueba de contrato de modelos.".to_string(),
            severity: Severity::Medium,
            confidence: Confidence::High,
            impacts: vec![Impact::Startup, Impact::Performance],
            evidence: vec![Evidence {
                source: "startup_collector".to_string(),
                metric: "active_items".to_string(),
                value: "8".to_string(),
                expected: Some("< 6".to_string()),
                message: "Hay varios elementos activos.".to_string(),
                technical_data: None,
            }],
            recommendations: vec![Recommendation {
                id: "startup.review".to_string(),
                title: "Revisar inicio".to_string(),
                explanation: "Revisar aplicaciones de usuario.".to_string(),
                expected_impact: Some("medium".to_string()),
                risk: RiskLevel::Low,
                action_id: None,
            }],
            detected_at: 1,
        };

        let json = serde_json::to_string(&finding).expect("serialize finding");
        assert!(json.contains("\"severity\":\"medium\""));
        assert!(json.contains("\"confidence\":\"high\""));
        assert!(json.contains("\"startup\""));
    }

    #[test]
    fn action_result_supports_verification_and_rollback() {
        let result = ActionResult {
            action_id: "startup.disable".to_string(),
            target_id: "example".to_string(),
            success: true,
            changed: true,
            before: Some("active".to_string()),
            after: Some("disabled".to_string()),
            verified: true,
            rollback_available: true,
            message: "Cambio verificado.".to_string(),
            executed_at: 1,
        };

        assert!(result.success);
        assert!(result.verified);
        assert!(result.rollback_available);
    }
}

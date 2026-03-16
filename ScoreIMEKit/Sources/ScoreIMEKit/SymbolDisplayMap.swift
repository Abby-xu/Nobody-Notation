/// Maps model output labels to display-ready music notation symbols.
/// The model uses labels like "m-m", "b-b", "o|", "tri" to avoid naming conflicts
/// with Swift classes. This map converts them to proper display characters.
public enum SymbolDisplayMap {
    public static func displayString(for modelLabel: String) -> String {
        switch modelLabel {
        case "m-m": return "m"
        case "b-b": return "♭"
        case "o|":  return "ø"
        case "tri": return "△"
        case "#":   return "♯"
        case "-":   return "–"
        case "o":   return "°"
        default:    return modelLabel
        }
    }
}

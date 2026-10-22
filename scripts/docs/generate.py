#!/usr/bin/env python3

import yaml
from pathlib import Path
from typing import Dict, List, Any
from jinja2 import Environment, FileSystemLoader
import sys

# Windows consoles default to a legacy codepage (e.g. cp1252), which
# cannot encode the checkmarks this script prints. Force UTF-8 output so
# it also runs on Windows, not just UTF-8 Linux hosts/CI.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


class ComposeParser:
    """Parse docker-compose files and extract service metadata."""
    
    def __init__(self, services_dir: str = "services"):
        self.services_dir = Path(services_dir)
        self.services: Dict[str, List[Dict[str, Any]]] = {}
        
    def parse_all(self):
        """Parse all compose files in services directory."""
        for category_dir in sorted(self.services_dir.iterdir()):
            if not category_dir.is_dir():
                continue
            
            category = category_dir.name
            self.services[category] = []
            
            for service_dir in sorted(category_dir.iterdir()):
                if not service_dir.is_dir():
                    continue
                
                compose_file = service_dir / "compose.yaml"
                if compose_file.exists():
                    service_data = self._parse_compose(service_dir.name, compose_file)
                    if service_data:
                        self.services[category].append(service_data)
    
    def get_all_traefik_hostnames(self) -> List[str]:
        """Get all unique Traefik hostnames from all services."""
        hostnames = set()
        for category_services in self.services.values():
            for svc in category_services:
                if svc["hostname"] != "none":
                    hostnames.add(svc["hostname"])
        return sorted(hostnames)

    def get_service_network_memberships(self) -> Dict[str, List[str]]:
        """Build mapping of services to networks they use."""
        memberships = {}

        for category_services in self.services.values():
            for svc in category_services:
                networks = svc["networks"]

                # Docker host networking does not appear under networks:
                # it is configured as network_mode: host
                if svc.get("network_mode") == "host":
                    networks = ["Host networking mode"]

                memberships[svc["name"]] = sorted(networks)

        return memberships
    
    def _parse_compose(self, service_name: str, compose_path: Path) -> Dict[str, Any]:
        """Parse a single compose.yaml file."""
        try:
            with open(compose_path, encoding="utf-8") as f:
                compose = yaml.safe_load(f)
        except Exception as e:
            print(f"Warning: Failed to parse {compose_path}: {e}", file=sys.stderr)
            return None
        
        if not compose or "services" not in compose:
            return None
        
        # Get the main service (first one, or one matching the directory name)
        services = compose["services"]
        main_service = services.get(service_name, next(iter(services.values())))
        
        # Extract metadata
        hostname = self._extract_traefik_hostname(main_service)
        description = self._extract_description(main_service)
        networks = self._extract_networks(main_service)
        network_mode = main_service.get("network_mode")
        
        return {
            "name": service_name,
            "hostname": hostname,
            "description": description,
            "networks": networks,
            "network_mode": network_mode,
        }
    
    def _extract_traefik_hostname(self, service: Dict) -> str:
        """Extract Traefik hostname from service labels."""
        labels = service.get("labels", {})
        
        for key, value in labels.items():
            if "traefik" in key and "rule" in key:
                # Extract hostname from Host(`...`) pattern
                if "Host(`" in value:
                    start = value.index("Host(`") + 6
                    end = value.index("`)", start)
                    return value[start:end]
        
        return "none"
    
    def _extract_description(self, service: Dict) -> str:
        """Extract description from docs.description label."""
        labels = service.get("labels", {})
        return labels.get("docs.description", "No description")
    
    def _extract_networks(self, service: Dict) -> List[str]:
        """Extract networks this service is connected to."""
        networks = service.get("networks", {})
        if isinstance(networks, dict):
            return list(networks.keys())
        elif isinstance(networks, list):
            return networks
        return []
    
    def get_services_by_category(self, category: str) -> List[Dict]:
        """Get all services in a category."""
        return self.services.get(category, [])
    
    def build_service_table(self, category: str) -> str:
        """Build markdown table for a service category."""
        services = self.get_services_by_category(category)
        if not services:
            return ""
        
        lines = [
            "| Service | Traefik hostname | Description |",
            "| --- | --- | --- |"
        ]
        
        for svc in services:
            name = svc["name"]
            hostname = svc["hostname"]
            desc = svc["description"].replace("|", "\\|")
            lines.append(f"| {name} | {hostname} | {desc} |")
        
        return "\n".join(lines)
    
    def build_service_memberships_table(self) -> str:
        """Build markdown table for service network memberships."""
        memberships = self.get_service_network_memberships()

        if not memberships:
            return "No network memberships"

        lines = [
            "| Service | Network(s) |",
            "| --- | --- |"
        ]

        for service_name in sorted(memberships.keys()):
            networks = memberships[service_name]
            network_list = " · ".join(f"`{net}`" for net in networks)
            lines.append(f"| {service_name} | {network_list} |")

        return "\n".join(lines)
    
    def build_hosts_file(self) -> str:
        """Generate /etc/hosts entries for all Traefik hostnames."""
        hostnames = self.get_all_traefik_hostnames()
        
        lines = []
        for hostname in hostnames:
            lines.append(f"127.0.0.1 {hostname}")
        
        return "\n".join(lines)


def main():
    # Get homelab root (2 levels up from script)
    script_dir = Path(__file__).parent
    homelab_root = script_dir.parent.parent
    docs_dir = homelab_root / "docs"
    
    # Create output directory if it doesn't exist
    output_dir = docs_dir / "generated"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Parse compose files
    parser = ComposeParser(homelab_root / "services")
    parser.parse_all()
    
    # Setup Jinja2
    env = Environment(loader=FileSystemLoader(docs_dir / "templates"))

    def render_template(template_name: str, output_path: Path, data: dict):
        template = env.get_template(template_name)

        content = template.render(**data)

        output_path.write_text(content, encoding="utf-8")
        print(f"✓ Generated {output_path}")
    
    # Build data for template
    data = {
        "core_table": parser.build_service_table("core"),
        "apps_table": parser.build_service_table("apps"),
        "mail_table": parser.build_service_table("mail"),
        "metrics_table": parser.build_service_table("metrics"),
        "service_memberships_table": parser.build_service_memberships_table(),
        "hosts_file": parser.build_hosts_file(),
    }
    
    render_template(
        "services.md.jinja2",
        docs_dir / "generated" / "services.md",
        data
    )

    render_template(
        "networking.md.jinja2",
        docs_dir / "generated" / "networking.md",
        data
    )

    render_template(
        "local-debugging.md.jinja2",
        docs_dir / "generated" / "local-debugging.md",
        data
    )
    
    print(f"✓ Documentation generated successfully")


if __name__ == "__main__":
    main()
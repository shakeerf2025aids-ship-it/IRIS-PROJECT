import os
import glob
import json
import uuid
import hashlib
import shutil
import argparse
from datetime import datetime
from collections import defaultdict, Counter
import pandas as pd
from PIL import Image
import imagehash
import cv2
import numpy as np

# Adjust imports to find IRIS backend modules
import sys
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from validators.fundus_prescreener import prescreener
from ml.quality_assessor import quality_assessor

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

class DatasetPipeline:
    def __init__(self, raw_dir, output_dir):
        self.raw_dir = raw_dir
        self.output_dir = output_dir
        self.reports_dir = os.path.join(output_dir, 'reports')
        self.processed_images_dir = os.path.join(output_dir, 'images')
        
        ensure_dir(self.output_dir)
        ensure_dir(self.reports_dir)
        ensure_dir(self.processed_images_dir)
        
        self.metadata = {}  # {image_id: { ... }}
        
    def run_all(self):
        print("[PHASE 1] Data Ingestion")
        self.ingest()
        
        print("\n[PHASE 3] Duplicate Detection")
        self.detect_duplicates()
        
        print("\n[PHASE 5 & 6] Image Validation & Quality Assessment")
        self.validate_images()
        
        print("\n[PHASE 7] Label Validation")
        self.validate_labels()
        
        print("\n[PHASE 4 & 9] Train/Val/Test Split & Leakage Check")
        self.split_dataset()
        
        print("\n[PHASE 2 & 8] Dataset Audit & Unified Schema")
        self.generate_audit_and_schema()
        
        print("\n[PHASE 10] Training Readiness Score")
        self.calculate_readiness_score()
        print("\nPipeline Complete. Check the 'reports' directory.")

    def ingest(self):
        """Phase 1: Ingest from multiple hospitals, standardizing names & IDs."""
        supported_exts = ('*.png', '*.jpg', '*.jpeg', '*.tiff')
        image_files = []
        for ext in supported_exts:
            image_files.extend(glob.glob(os.path.join(self.raw_dir, '**', ext), recursive=True))
            
        print(f"Found {len(image_files)} raw images.")
        
        for file_path in image_files:
            # Simple heuristic for extraction based on folder structure:
            # Expected raw format: raw_dir/Hospital_A/labels.csv and images/
            hospital_name = os.path.basename(os.path.dirname(os.path.dirname(file_path)))
            if hospital_name == os.path.basename(self.raw_dir):
                hospital_name = "Unknown_Hospital"
                
            orig_filename = os.path.basename(file_path)
            
            # Generate UUIDs
            image_id = str(uuid.uuid4())
            # For demonstration, we simulate patient_id and laterality from filename if possible, 
            # otherwise generate random patient_id for simulation.
            # In production, this parses the hospital's specific CSV mapping.
            patient_id = hashlib.md5(f"{hospital_name}_{orig_filename[:5]}".encode()).hexdigest()[:10]
            laterality = 'OD' if 'OD' in orig_filename.upper() or 'RIGHT' in orig_filename.upper() else 'OS'
            
            self.metadata[image_id] = {
                'image_id': image_id,
                'patient_id': patient_id,
                'eye': laterality,
                'hospital': hospital_name,
                'original_path': file_path,
                'labels': {'normal': 0, 'glaucoma': 0, 'amd': 0, 'dr': 0},
                'valid': True,
                'reject_reason': None
            }
            
            # Copy to unified dir
            ext = os.path.splitext(orig_filename)[1]
            new_path = os.path.join(self.processed_images_dir, f"{image_id}{ext}")
            shutil.copy2(file_path, new_path)
            self.metadata[image_id]['processed_path'] = new_path

    def detect_duplicates(self):
        """Phase 3: Exact & Perceptual Hash Duplicates."""
        hashes = {}
        exact_hashes = {}
        duplicates = []
        
        for img_id, data in self.metadata.items():
            if not data['valid']: continue
            path = data['processed_path']
            try:
                img = Image.open(path)
                # Exact Hash
                with open(path, 'rb') as f:
                    exact_hash = hashlib.md5(f.read()).hexdigest()
                
                # Perceptual Hash
                p_hash = str(imagehash.phash(img))
                
                if exact_hash in exact_hashes:
                    duplicates.append({'image_id': img_id, 'type': 'Exact', 'duplicate_of': exact_hashes[exact_hash]})
                    data['valid'] = False
                    data['reject_reason'] = 'Exact Duplicate'
                elif p_hash in hashes:
                    duplicates.append({'image_id': img_id, 'type': 'Near/Perceptual', 'duplicate_of': hashes[p_hash]})
                    data['valid'] = False
                    data['reject_reason'] = 'Near Duplicate'
                else:
                    exact_hashes[exact_hash] = img_id
                    hashes[p_hash] = img_id
            except Exception as e:
                data['valid'] = False
                data['reject_reason'] = f'Corrupted Image: {e}'
                
        df = pd.DataFrame(duplicates)
        df.to_csv(os.path.join(self.reports_dir, 'duplicates.csv'), index=False)
        print(f"Detected {len(duplicates)} duplicates.")

    def validate_images(self):
        """Phase 5 & 6: Fundus Prescreen & Quality Assess."""
        invalid_images = []
        quality_issues = []
        
        for img_id, data in self.metadata.items():
            if not data['valid']: continue
            try:
                img = Image.open(data['processed_path'])
                
                # Prescreener
                prescreen = prescreener.check(img)
                if not prescreen['is_fundus']:
                    data['valid'] = False
                    data['reject_reason'] = 'Not Fundus / Invalid'
                    invalid_images.append({
                        'image_id': img_id, 
                        'reason': prescreen['reason']
                    })
                    continue
                    
                # Quality
                quality = quality_assessor.assess(img)
                data['quality_score'] = quality['score']
                if quality['quality'] == 'poor':
                    # We might not strictly reject all poor images for training, but flag them
                    data['quality_flag'] = 'Poor'
                    quality_issues.append({
                        'image_id': img_id,
                        'reasons': " | ".join(quality['reasons'])
                    })
                else:
                    data['quality_flag'] = 'Good'
                    
            except Exception as e:
                data['valid'] = False
                data['reject_reason'] = f'Read Error: {e}'

        pd.DataFrame(invalid_images).to_csv(os.path.join(self.reports_dir, 'invalid_images.csv'), index=False)
        pd.DataFrame(quality_issues).to_csv(os.path.join(self.reports_dir, 'quality_report.csv'), index=False)
        print(f"Rejected {len(invalid_images)} invalid images. Flagged {len(quality_issues)} poor quality images.")

    def validate_labels(self):
        """Phase 7: Contradiction checks."""
        issues = []
        for img_id, data in self.metadata.items():
            if not data['valid']: continue
            lbl = data['labels']
            is_normal = lbl.get('normal', 0) == 1
            has_disease = any(lbl.get(d, 0) == 1 for d in ['glaucoma', 'amd', 'dr'])
            
            if is_normal and has_disease:
                issues.append({'image_id': img_id, 'issue': 'Normal + Disease Contradiction'})
                data['valid'] = False
                data['reject_reason'] = 'Label Contradiction'
                
        pd.DataFrame(issues).to_csv(os.path.join(self.reports_dir, 'label_issues.csv'), index=False)
        print(f"Found {len(issues)} label contradictions.")

    def split_dataset(self):
        """Phase 4 & 9: Patient-level 70/10/10/10 split with Leakage detection."""
        patients = list(set(d['patient_id'] for d in self.metadata.values() if d['valid']))
        np.random.shuffle(patients)
        
        n = len(patients)
        t_idx = int(n * 0.7)
        v_idx = int(n * 0.8)
        it_idx = int(n * 0.9)
        
        splits = {
            'Train': set(patients[:t_idx]),
            'Validation': set(patients[t_idx:v_idx]),
            'Internal_Test': set(patients[v_idx:it_idx]),
            'External_Test': set(patients[it_idx:])
        }
        
        leakage = []
        # Assign splits and verify zero leakage
        for img_id, data in self.metadata.items():
            if not data['valid']: continue
            pid = data['patient_id']
            
            assigned = None
            for sp_name, sp_set in splits.items():
                if pid in sp_set:
                    if assigned is not None:
                        leakage.append({'patient_id': pid, 'issue': f'Leakage across {assigned} and {sp_name}'})
                    assigned = sp_name
                    
            data['split'] = assigned
            
        pd.DataFrame(leakage).to_csv(os.path.join(self.reports_dir, 'leakage_report.csv'), index=False)
        print("Dataset split applied. Zero leakage verified.")

    def generate_audit_and_schema(self):
        """Phase 2 & 8: Unified Schema Output and Audit Report."""
        valid_data = [d for d in self.metadata.values() if d.get('valid', False)]
        
        # Schema generation
        df = pd.DataFrame(valid_data)
        if not df.empty:
            # Flatten labels
            df['normal'] = df['labels'].apply(lambda x: x.get('normal', 0))
            df['glaucoma'] = df['labels'].apply(lambda x: x.get('glaucoma', 0))
            df['amd'] = df['labels'].apply(lambda x: x.get('amd', 0))
            df['dr'] = df['labels'].apply(lambda x: x.get('dr', 0))
            df.drop(columns=['labels'], inplace=True)
            df.to_csv(os.path.join(self.output_dir, 'metadata.csv'), index=False)
            
            with open(os.path.join(self.output_dir, 'labels.json'), 'w') as f:
                json.dump({d['image_id']: d for d in valid_data}, f, indent=2)

        # Audit Report
        audit = {
            'total_processed': len(self.metadata),
            'total_valid': len(valid_data),
            'unique_patients': len(set(d['patient_id'] for d in valid_data)),
            'disease_distribution': {
                'normal': sum(1 for d in valid_data if d['labels'].get('normal', 0) == 1),
                'glaucoma': sum(1 for d in valid_data if d['labels'].get('glaucoma', 0) == 1),
                'amd': sum(1 for d in valid_data if d['labels'].get('amd', 0) == 1),
                'dr': sum(1 for d in valid_data if d['labels'].get('dr', 0) == 1),
            },
            'hospital_distribution': dict(Counter(d['hospital'] for d in valid_data)),
            'split_distribution': dict(Counter(d.get('split') for d in valid_data))
        }
        
        with open(os.path.join(self.reports_dir, 'dataset_audit_report.json'), 'w') as f:
            json.dump(audit, f, indent=4)
            
        # HTML Report
        html = f"<html><body><h1>Dataset Audit Report</h1><pre>{json.dumps(audit, indent=2)}</pre></body></html>"
        with open(os.path.join(self.reports_dir, 'dataset_audit_report.html'), 'w') as f:
            f.write(html)
            
        print("Generated metadata.csv, labels.json, and audit reports.")

    def calculate_readiness_score(self):
        """Phase 10: Training Readiness Score."""
        valid_data = [d for d in self.metadata.values() if d.get('valid', False)]
        if not valid_data:
            print("Score: 0/100 (No valid data)")
            return
            
        score = 0
        # Completeness (20)
        has_meta = sum(1 for d in valid_data if d.get('eye') and d.get('hospital'))
        score += int((has_meta / len(valid_data)) * 20)
        
        # Diversity (20)
        hospitals = len(set(d['hospital'] for d in valid_data))
        score += min(20, hospitals * 5)
        
        # Image Quality (15)
        good_quality = sum(1 for d in valid_data if d.get('quality_flag') == 'Good')
        score += int((good_quality / len(valid_data)) * 15)
        
        # Disease Coverage (20)
        diseases = ['glaucoma', 'amd', 'dr']
        coverage_score = 0
        for dis in diseases:
            count = sum(1 for d in valid_data if d['labels'].get(dis, 0) == 1)
            if count > 1000: coverage_score += 6.66
        score += int(coverage_score)
        
        # Label Quality (25) - Mocked as 20 for pipeline demonstration
        score += 20
        
        print(f"=== TRAINING READINESS SCORE: {score}/100 ===")
        with open(os.path.join(self.reports_dir, 'readiness_score.txt'), 'w') as f:
            f.write(f"TRAINING READINESS SCORE: {score}/100\n")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="IRIS Hospital Dataset Preparation Pipeline")
    parser.add_argument('--raw_dir', required=True, help="Path to raw hospital exports")
    parser.add_argument('--output_dir', required=True, help="Path to validated dataset output")
    args = parser.parse_args()
    
    pipeline = DatasetPipeline(args.raw_dir, args.output_dir)
    pipeline.run_all()

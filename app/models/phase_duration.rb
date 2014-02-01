#encoding: utf-8
# Copyright (c) 2013 Universidade Federal Fluminense (UFF).
# This file is part of SAPOS. Please, consult the license terms in the LICENSE file.

class PhaseDuration < ActiveRecord::Base
  attr_accessible :deadline_semesters, :deadline_months, :deadline_days

  belongs_to :phase
  belongs_to :level

  has_paper_trail

  validates :phase, :presence => true
  validates :level, :presence => true

  validate :deadline_validation


  before_destroy :validate_destroy
  after_save :create_phase_completion

  def to_label
    "#{deadline_semesters} períodos, #{deadline_months} meses e #{deadline_days} dias"
  end

  def deadline_validation
    if (([0,nil].include?(self.deadline_semesters)) && ([0,nil].include?(self.deadline_months)) && ([0,nil].include?(self.deadline_days)))
      errors.add(:deadline, I18n.t("activerecord.errors.models.phase_duration.blank_deadline"))
    end
  end

  def duration
    {:semesters => self.deadline_semesters, :months => self.deadline_months, :days => self.deadline_days}
  end


  def validate_destroy
    return true if phase.nil? or level.nil?
    has_deferral = phase.deferral_type.any? do |deferral_type|
      deferral_type.deferrals.any? do |deferral|
        deferral.enrollment.level == level
      end
    end
    has_level = level.enrollments.any? do |enrollment| 
      enrollment.accomplishments.any? do |accomplishment|
        accomplishment.phase == phase
      end
    end
    if has_deferral
      errors.add(:base, I18n.t("activerecord.errors.models.phase_duration.has_deferral"))
      phase.errors.add(:base, I18n.t("activerecord.errors.models.phase.phase_duration_has_deferral", :level => level.to_label))
    end
    if has_level
      errors.add(:base, I18n.t("activerecord.errors.models.phase_duration.has_level"))
      phase.errors.add(:base, I18n.t("activerecord.errors.models.phase.phase_duration_has_level", :level => level.to_label))
    end
    !has_deferral and !has_level
  end

  def create_phase_completion()
    PhaseCompletion.joins(:enrollment).where(:phase_id => phase.id, :enrollments => {:level_id => level.id}).destroy_all
    
    Enrollment.where(:level_id => level_id).each do |enrollment|
      completion_date = nil

      phase_accomplishment = enrollment.accomplishments.where(:phase_id => phase.id)[0]
      completion_date = phase_accomplishment.conclusion_date unless phase_accomplishment.nil?

      phase_deferrals = enrollment.deferrals.select { |deferral| deferral.deferral_type.phase == phase}
      if phase_deferrals.empty?
        due_date = phase.calculate_end_date(enrollment.admission_date, deadline_semesters, deadline_months, deadline_days)
      else
        total_time = duration
        phase_deferrals.each do |deferral|
          deferral_duration = deferral.deferral_type.duration
          (total_time.keys | deferral_duration.keys).each do |key|
            total_time[key] += deferral_duration[key].to_i
          end
        end
        due_date = phase.calculate_end_date(enrollment.admission_date, total_time[:semesters], total_time[:months], total_time[:days])
      end

      PhaseCompletion.create(:enrollment_id=>enrollment.id, :phase_id=>phase.id, :completion_date=>completion_date, :due_date=>due_date)
    end
  end
end

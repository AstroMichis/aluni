# The public action plan page (/plan): the integrated project proposal, draft 0.3, for the
# Space Apps judges. Informational only; the copy lives in config/locales/*/views/*.plan.yml
# as blocks per section, rendered by plan/_blocks.
class PlanController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  # Section keys under plan.show.sections, in reading order; the view and the spec iterate them.
  SECTIONS = %w[
    read executive t1 t2 t3 t4 t5 t5b t5c t5d t6 t7 t8 t9
    t10 t11 t12 t13 t14 t15 t16 t17 t18 open_questions sources
  ].freeze

  def show
  end
end
